/**
 * @file ui_adaptive_deck.c
 * @brief MCU 终端自适应卡片中控界面实现 (纯百分比与 Flexbox 弹性流式排版)
 */

#include "ui_adaptive_deck.h"
#include "ui_theme_tokens.h"
#include <stdio.h>

static lv_obj_t *s_scr = NULL;
static lv_obj_t *s_curtain_val_label = NULL;
static lv_obj_t *s_light_val_label = NULL;

static void btn_curtain_cmd_cb(lv_event_t *e) {
    int target_pos = (int)(intptr_t)lv_event_get_user_data(e);
    // 这里将指令派发至 MCU 本地 MQTT 或总线 (sh/h01/C01/cmd)
    ui_adaptive_deck_update_device("C01", target_pos);
}

static void btn_light_cmd_cb(lv_event_t *e) {
    int on = (int)(intptr_t)lv_event_get_user_data(e);
    ui_adaptive_deck_update_device("L01", on);
}

static lv_obj_t *create_action_button(lv_obj_t *parent, const char *text, bool is_active,
                                      lv_event_cb_t cb, void *user_data) {
    lv_obj_t *btn = lv_btn_create(parent);
    lv_obj_set_style_bg_color(btn, is_active ? UI_COLOR_BTN_ACTIVE : UI_COLOR_BTN_NORMAL, 0);
    lv_obj_set_style_border_color(btn, UI_COLOR_BTN_BORDER, 0);
    lv_obj_set_style_border_width(btn, 1, 0);
    lv_obj_set_style_radius(btn, TOKEN_RADIUS_BTN, 0);
    lv_obj_set_style_pad_ver(btn, TOKEN_PADDING_CARD / 2, 0);
    lv_obj_set_style_pad_hor(btn, TOKEN_PADDING_CARD, 0);
    lv_obj_add_event_cb(btn, cb, LV_EVENT_CLICKED, user_data);

    lv_obj_t *lbl = lv_label_create(btn);
    lv_label_set_text(lbl, text);
    lv_obj_set_style_text_font(lbl, TOKEN_FONT_BODY, 0);
    lv_obj_set_style_text_color(lbl, UI_COLOR_TEXT_PRIMARY, 0);
    lv_obj_center(lbl);
    return btn;
}

static lv_obj_t *create_category_card(lv_obj_t *parent, const char *title, const char *badge) {
    lv_obj_t *card = lv_obj_create(parent);
    lv_obj_set_width(card, TOKEN_CARD_WIDTH_PCT);
    lv_obj_set_height(card, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_color(card, UI_COLOR_CARD_BG, 0);
    lv_obj_set_style_border_color(card, UI_COLOR_CARD_BORDER, 0);
    lv_obj_set_style_border_width(card, 1, 0);
    lv_obj_set_style_radius(card, TOKEN_RADIUS_CARD, 0);
    lv_obj_set_style_pad_all(card, TOKEN_PADDING_CARD, 0);
    lv_obj_set_flex_flow(card, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_flex_align(card, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START);

    /* 标题行容器 */
    lv_obj_t *hdr = lv_obj_create(card);
    lv_obj_set_width(hdr, lv_pct(100));
    lv_obj_set_height(hdr, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(hdr, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(hdr, 0, 0);
    lv_obj_set_style_pad_all(hdr, 0, 0);
    lv_obj_set_flex_flow(hdr, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(hdr, LV_FLEX_ALIGN_SPACE_BETWEEN, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    lv_obj_t *t_lbl = lv_label_create(hdr);
    lv_label_set_text(t_lbl, title);
    lv_obj_set_style_text_font(t_lbl, TOKEN_FONT_TITLE, 0);
    lv_obj_set_style_text_color(t_lbl, UI_COLOR_TEXT_PRIMARY, 0);

    lv_obj_t *b_lbl = lv_label_create(hdr);
    lv_label_set_text(b_lbl, badge);
    lv_obj_set_style_text_font(b_lbl, TOKEN_FONT_CAPTION, 0);
    lv_obj_set_style_text_color(b_lbl, UI_COLOR_ACCENT_AMBER, 0);

    return card;
}

void ui_adaptive_deck_create(void) {
    s_scr = lv_scr_act();
    lv_obj_set_style_bg_color(s_scr, UI_COLOR_BG, 0);
    lv_obj_set_style_pad_all(s_scr, TOKEN_PADDING_SCREEN, 0);
    lv_obj_set_flex_flow(s_scr, LV_FLEX_FLOW_COLUMN);

    /* ==================== 1. 顶部状态栏 (Header Bar) ==================== */
    lv_obj_t *top_bar = lv_obj_create(s_scr);
    lv_obj_set_width(top_bar, lv_pct(100));
    lv_obj_set_height(top_bar, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(top_bar, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(top_bar, 0, 0);
    lv_obj_set_style_pad_hor(top_bar, TOKEN_PADDING_SCREEN, 0);
    lv_obj_set_style_pad_ver(top_bar, 2, 0);
    lv_obj_set_flex_flow(top_bar, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(top_bar, LV_FLEX_ALIGN_SPACE_BETWEEN, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    /* 标题 + 在线指示绿点 */
    lv_obj_t *title_box = lv_obj_create(top_bar);
    lv_obj_set_size(title_box, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(title_box, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(title_box, 0, 0);
    lv_obj_set_style_pad_all(title_box, 0, 0);
    lv_obj_set_flex_flow(title_box, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(title_box, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    lv_obj_t *dot = lv_obj_create(title_box);
    lv_obj_set_size(dot, 8, 8);
    lv_obj_set_style_bg_color(dot, UI_COLOR_ACCENT_GREEN, 0);
    lv_obj_set_style_radius(dot, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_border_width(dot, 0, 0);

    lv_obj_t *app_name = lv_label_create(title_box);
    lv_label_set_text(app_name, "智慧家居中控终端");
    lv_obj_set_style_text_font(app_name, TOKEN_FONT_TITLE, 0);
    lv_obj_set_style_text_color(app_name, UI_COLOR_TEXT_PRIMARY, 0);

    /* 状态指示 */
    lv_obj_t *status_txt = lv_label_create(top_bar);
    lv_label_set_text(status_txt, "总线在线");
    lv_obj_set_style_text_font(status_txt, TOKEN_FONT_CAPTION, 0);
    lv_obj_set_style_text_color(status_txt, UI_COLOR_TEXT_SECONDARY, 0);

    /* ==================== 2. 自适应中控卡片流 (Flexbox Deck) ==================== */
    lv_obj_t *deck = lv_obj_create(s_scr);
    lv_obj_set_width(deck, lv_pct(100));
    lv_obj_set_flex_grow(deck, 1); // 撑满中间剩余可用高度并允许滚动
    lv_obj_set_style_bg_opa(deck, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(deck, 0, 0);
    lv_obj_set_style_pad_all(deck, 0, 0);
    /* 核心魔法: 弹性自动折行，宽屏排2列，窄屏排1列 */
    lv_obj_set_flex_flow(deck, LV_FLEX_FLOW_ROW_WRAP);
    lv_obj_set_flex_align(deck, LV_FLEX_ALIGN_SPACE_BETWEEN, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START);

    /* --- 卡片 1: 智能窗帘 --- */
    lv_obj_t *card_curtain = create_category_card(deck, "智能窗帘", "1 台已连接");
    s_curtain_val_label = lv_label_create(card_curtain);
    lv_label_set_text(s_curtain_val_label, "当前开度: 50% (半开)");
    lv_obj_set_style_text_font(s_curtain_val_label, TOKEN_FONT_BODY, 0);
    lv_obj_set_style_text_color(s_curtain_val_label, UI_COLOR_TEXT_SECONDARY, 0);

    lv_obj_t *btn_row_c = lv_obj_create(card_curtain);
    lv_obj_set_width(btn_row_c, lv_pct(100));
    lv_obj_set_height(btn_row_c, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(btn_row_c, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(btn_row_c, 0, 0);
    lv_obj_set_style_pad_all(btn_row_c, 0, 0);
    lv_obj_set_flex_flow(btn_row_c, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(btn_row_c, LV_FLEX_ALIGN_SPACE_BETWEEN, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    create_action_button(btn_row_c, "全关", false, btn_curtain_cmd_cb, (void *)0);
    create_action_button(btn_row_c, "半开", true, btn_curtain_cmd_cb, (void *)50);
    create_action_button(btn_row_c, "全开", false, btn_curtain_cmd_cb, (void *)100);

    /* --- 卡片 2: 全屋灯光 --- */
    lv_obj_t *card_light = create_category_card(deck, "全屋灯光", "1 盏开启");
    s_light_val_label = lv_label_create(card_light);
    lv_label_set_text(s_light_val_label, "客厅主灯: 暖黄 (开启)");
    lv_obj_set_style_text_font(s_light_val_label, TOKEN_FONT_BODY, 0);
    lv_obj_set_style_text_color(s_light_val_label, UI_COLOR_TEXT_SECONDARY, 0);

    lv_obj_t *btn_row_l = lv_obj_create(card_light);
    lv_obj_set_width(btn_row_l, lv_pct(100));
    lv_obj_set_height(btn_row_l, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(btn_row_l, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(btn_row_l, 0, 0);
    lv_obj_set_style_pad_all(btn_row_l, 0, 0);
    lv_obj_set_flex_flow(btn_row_l, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(btn_row_l, LV_FLEX_ALIGN_SPACE_BETWEEN, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    create_action_button(btn_row_l, "关灯", false, btn_light_cmd_cb, (void *)0);
    create_action_button(btn_row_l, "开灯", true, btn_light_cmd_cb, (void *)1);

    /* --- 卡片 3: 环境温控 --- */
    lv_obj_t *card_climate = create_category_card(deck, "环境温控", "26.5°C 舒适");
    lv_obj_t *cl_val = lv_label_create(card_climate);
    lv_label_set_text(cl_val, "室内温度 26.5°C | 湿度 55%");
    lv_obj_set_style_text_font(cl_val, TOKEN_FONT_BODY, 0);
    lv_obj_set_style_text_color(cl_val, UI_COLOR_TEXT_SECONDARY, 0);

    /* --- 卡片 4: 智能插座 --- */
    lv_obj_t *card_power = create_category_card(deck, "智能插座", "实时功率 45W");
    lv_obj_t *pw_val = lv_label_create(card_power);
    lv_label_set_text(pw_val, "客厅电视插座: 供电正常");
    lv_obj_set_style_text_font(pw_val, TOKEN_FONT_BODY, 0);
    lv_obj_set_style_text_color(pw_val, UI_COLOR_TEXT_SECONDARY, 0);

    /* ==================== 3. 底部房间快速导航药丸条 (Room Pills Bar) ==================== */
    lv_obj_t *room_bar = lv_obj_create(s_scr);
    lv_obj_set_width(room_bar, lv_pct(100));
    lv_obj_set_height(room_bar, LV_SIZE_CONTENT);
    lv_obj_set_style_bg_opa(room_bar, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(room_bar, 0, 0);
    lv_obj_set_style_pad_all(room_bar, 0, 0);
    lv_obj_set_flex_flow(room_bar, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(room_bar, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    const char *rooms[] = {"全部", "客厅", "主卧(南)", "次卧(北)", "厨房"};
    for (int i = 0; i < 5; i++) {
        lv_obj_t *pill = lv_btn_create(room_bar);
        lv_obj_set_style_bg_color(pill, (i == 0) ? UI_COLOR_BTN_ACTIVE : UI_COLOR_CARD_BG, 0);
        lv_obj_set_style_border_color(pill, UI_COLOR_CARD_BORDER, 0);
        lv_obj_set_style_border_width(pill, 1, 0);
        lv_obj_set_style_radius(pill, LV_RADIUS_CIRCLE, 0);
        lv_obj_set_style_pad_ver(pill, 4, 0);
        lv_obj_set_style_pad_hor(pill, 10, 0);

        lv_obj_t *r_lbl = lv_label_create(pill);
        lv_label_set_text(r_lbl, rooms[i]);
        lv_obj_set_style_text_font(r_lbl, TOKEN_FONT_CAPTION, 0);
        lv_obj_set_style_text_color(r_lbl, (i == 0) ? UI_COLOR_TEXT_PRIMARY : UI_COLOR_TEXT_SECONDARY, 0);
    }
}

void ui_adaptive_deck_update_device(const char *device_id, int state_val) {
    if (device_id == NULL) return;

    if (strcmp(device_id, "C01") == 0 && s_curtain_val_label != NULL) {
        char buf[64];
        snprintf(buf, sizeof(buf), "当前开度: %d%% (%s)", state_val,
                 state_val == 0 ? "全关" : (state_val == 100 ? "全开" : "运行中"));
        lv_label_set_text(s_curtain_val_label, buf);
    } else if (strcmp(device_id, "L01") == 0 && s_light_val_label != NULL) {
        lv_label_set_text(s_light_val_label, state_val ? "客厅主灯: 开启" : "客厅主灯: 关闭");
    }
}
