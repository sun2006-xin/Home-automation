/**
 * @file bsp_display.c
 * @brief MCU 终端通用显示屏硬件抽象驱动实现 (ESP-IDF v5.4 esp_lcd + LVGL 适配)
 */

#include "bsp_display.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_heap_caps.h"

static const char *TAG = "BSP_DISP";

static esp_lcd_panel_handle_t s_panel_handle = NULL;
static lv_disp_t *s_lv_disp = NULL;
static lv_disp_drv_t s_disp_drv;
static lv_disp_draw_buf_t s_disp_buf;

static bool notify_lvgl_flush_ready(esp_lcd_panel_io_handle_t panel_io,
                                    esp_lcd_panel_io_event_data_t *edata,
                                    void *user_ctx) {
    lv_disp_drv_t *disp_driver = (lv_disp_drv_t *)user_ctx;
    lv_disp_flush_ready(disp_driver);
    return false;
}

static void lvgl_flush_cb(lv_disp_drv_t *drv, const lv_area_t *area, lv_color_t *color_map) {
    int offsetx1 = area->x1;
    int offsetx2 = area->x2;
    int offsety1 = area->y1;
    int offsety2 = area->y2;

    /* 将 LVGL 渲染完成的像素块推入 SPI DMA 管道 */
    esp_lcd_panel_draw_bitmap(s_panel_handle, offsetx1, offsety1, offsetx2 + 1, offsety2 + 1, color_map);
}

void bsp_display_set_backlight(uint8_t brightness_percent) {
    if (BSP_PIN_NUM_BK_LIGHT >= 0) {
        if (brightness_percent > 0) {
            gpio_set_level(BSP_PIN_NUM_BK_LIGHT, BSP_LCD_BK_LIGHT_ON_LEVEL);
        } else {
            gpio_set_level(BSP_PIN_NUM_BK_LIGHT, !BSP_LCD_BK_LIGHT_ON_LEVEL);
        }
    }
}

lv_disp_t *bsp_display_get_lv_disp(void) {
    return s_lv_disp;
}

esp_err_t bsp_display_init(void) {
    ESP_LOGI(TAG, "初始化 MCU 显示屏硬件总线 (物理分辨率: %dx%d, 旋转: %d°)...",
             BSP_DISPLAY_HOR_RES, BSP_DISPLAY_VER_RES, BSP_DISPLAY_ROTATION_DEG);

    /* 1. 初始化背光控制引脚 */
    if (BSP_PIN_NUM_BK_LIGHT >= 0) {
        gpio_config_t bk_gpio_config = {
            .mode = GPIO_MODE_OUTPUT,
            .pin_bit_mask = 1ULL << BSP_PIN_NUM_BK_LIGHT,
        };
        gpio_config(&bk_gpio_config);
        bsp_display_set_backlight(0); // 初始黑屏防止白屏闪烁
    }

    /* 2. 初始化 SPI 主机总线 */
    spi_bus_config_t buscfg = {
        .sclk_io_num = BSP_PIN_NUM_SCLK,
        .mosi_io_num = BSP_PIN_NUM_MOSI,
        .miso_io_num = BSP_PIN_NUM_MISO,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = BSP_DISPLAY_HOR_RES * BSP_LCD_DMA_BUFFER_LINES * sizeof(lv_color_t),
    };
    esp_err_t ret = spi_bus_initialize(BSP_SPI_HOST_ID, &buscfg, SPI_DMA_CH_AUTO);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SPI 总线初始化失败: %d", ret);
        return ret;
    }

    /* 3. 创建 LCD Panel IO (绑定传输完成中断通知 LVGL) */
    esp_lcd_panel_io_handle_t io_handle = NULL;
    esp_lcd_panel_io_spi_config_t io_config = {
        .dc_gpio_num = BSP_PIN_NUM_LCD_DC,
        .cs_gpio_num = BSP_PIN_NUM_LCD_CS,
        .pclk_hz = BSP_LCD_PIXEL_CLOCK_HZ,
        .lcd_cmd_bits = 8,
        .lcd_param_bits = 8,
        .spi_mode = 0,
        .trans_queue_depth = 10,
        .on_color_trans_done = notify_lvgl_flush_ready,
        .user_ctx = &s_disp_drv,
    };
    ret = esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)BSP_SPI_HOST_ID, &io_config, &io_handle);
    if (ret != ESP_OK) return ret;

    /* 4. 创建显示面板驱动实例 (默认 ST7789，可通过配置切换) */
    esp_lcd_panel_dev_config_t panel_config = {
        .reset_gpio_num = BSP_PIN_NUM_LCD_RST,
        .rgb_endian = LCD_RGB_ENDIAN_BGR,
        .bits_per_pixel = 16,
    };

#if (BSP_DISPLAY_DRIVER_TYPE == BSP_DISPLAY_DRIVER_ST7789)
    ret = esp_lcd_new_panel_st7789(io_handle, &panel_config, &s_panel_handle);
#elif (BSP_DISPLAY_DRIVER_TYPE == BSP_DISPLAY_DRIVER_ILI9341)
    ret = esp_lcd_new_panel_ili9341(io_handle, &panel_config, &s_panel_handle);
#else
    ret = esp_lcd_new_panel_st7789(io_handle, &panel_config, &s_panel_handle);
#endif

    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "创建 LCD 控制器面板失败: %d", ret);
        return ret;
    }

    /* 5. 复位并初始化面板硬件寄存器 */
    esp_lcd_panel_reset(s_panel_handle);
    esp_lcd_panel_init(s_panel_handle);

    /* 6. 根据物理配置设置镜像翻转与坐标交换 (实现任意角度横竖屏) */
#if (BSP_DISPLAY_ROTATION_DEG == 90)
    esp_lcd_panel_swap_xy(s_panel_handle, true);
    esp_lcd_panel_mirror(s_panel_handle, false, true);
#elif (BSP_DISPLAY_ROTATION_DEG == 180)
    esp_lcd_panel_swap_xy(s_panel_handle, false);
    esp_lcd_panel_mirror(s_panel_handle, true, true);
#elif (BSP_DISPLAY_ROTATION_DEG == 270)
    esp_lcd_panel_swap_xy(s_panel_handle, true);
    esp_lcd_panel_mirror(s_panel_handle, true, false);
#else
    esp_lcd_panel_swap_xy(s_panel_handle, false);
    esp_lcd_panel_mirror(s_panel_handle, false, false);
#endif

    esp_lcd_panel_disp_on_off(s_panel_handle, true);

    /* 7. 分配 DMA 双缓冲区并注册至 LVGL 图形引擎 */
    size_t buffer_size = BSP_DISPLAY_HOR_RES * BSP_LCD_DMA_BUFFER_LINES * sizeof(lv_color_t);
    lv_color_t *buf1 = heap_caps_malloc(buffer_size, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    lv_color_t *buf2 = heap_caps_malloc(buffer_size, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);

    if (buf1 == NULL || buf2 == NULL) {
        ESP_LOGE(TAG, "DMA 显存分配不足 (需要 %zu 字节)", buffer_size * 2);
        return ESP_ERR_NO_MEM;
    }

    lv_disp_draw_buf_init(&s_disp_buf, buf1, buf2, BSP_DISPLAY_HOR_RES * BSP_LCD_DMA_BUFFER_LINES);

    lv_disp_drv_init(&s_disp_drv);
    s_disp_drv.hor_res = BSP_DISPLAY_HOR_RES;
    s_disp_drv.ver_res = BSP_DISPLAY_VER_RES;
    s_disp_drv.flush_cb = lvgl_flush_cb;
    s_disp_drv.draw_buf = &s_disp_buf;
    s_lv_disp = lv_disp_drv_register(&s_disp_drv);

    /* 8. 点亮背光 */
    bsp_display_set_backlight(100);
    ESP_LOGI(TAG, "MCU 显示屏硬件初始化完成，已向 LVGL 注册 %dx%d 画布",
             BSP_DISPLAY_HOR_RES, BSP_DISPLAY_VER_RES);

    return ESP_OK;
}
