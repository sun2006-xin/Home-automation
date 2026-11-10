# =========================================================================
# SmartHome Cloud Hub - Production Multi-Stage Dockerfile
# 专为阿里云 / 腾讯云 / AWS 等 Linux VPS 部署构建
# =========================================================================
FROM python:3.11-slim as builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# --- 运行阶段 ---
FROM python:3.11-slim

WORKDIR /app

# 从 builder 复制依赖
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# 复制源码
COPY . .

# 暴露服务端口
EXPOSE 8000

# 持久化数据目录挂载点
VOLUME ["/app/data"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
