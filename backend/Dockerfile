# syntax=docker/dockerfile:1
#
# Multi-stage: build a static binary in golang:alpine, ship from
# scratch+ca-certs to keep the runtime image tiny (~25MB).

FROM golang:1.22-alpine AS builder

# Use a CN-friendly Go module proxy by default. proxy.golang.org is
# unreachable from mainland China; goproxy.cn is a globally-accessible
# public mirror run by Qiniu — it works everywhere, just faster in CN.
# Override via `--build-arg GOPROXY=...` if you'd rather use upstream.
ARG GOPROXY=https://goproxy.cn,direct
ENV GOPROXY=$GOPROXY
ENV GOSUMDB=sum.golang.google.cn

WORKDIR /src

# Cache deps as a separate layer.
COPY go.mod go.sum ./
RUN go mod download

# Copy source. .dockerignore keeps host artifacts (.db, binaries) out.
COPY . .

# CGO_ENABLED=0 — modernc.org/sqlite is pure Go. No libc dependency,
# clean static binary, runs everywhere.
# -trimpath strips $HOME paths from the binary; -s -w drops the
# symbol table and DWARF info (~30% smaller binary).
RUN CGO_ENABLED=0 GOOS=linux go build \
        -trimpath \
        -ldflags='-s -w' \
        -o /out/wearorder-api \
        ./...

# ---------- runtime image ----------
FROM alpine:3.19

# ca-certificates so the binary can call HTTPS LLM endpoints; tzdata
# so log timestamps render in local time. Switch to a CN-friendly
# Alpine mirror first — dl-cdn.alpinelinux.org is slow / partially
# blocked from China; mirrors.aliyun.com is a public Alpine mirror
# that works globally too.
RUN sed -i 's|https://dl-cdn.alpinelinux.org|https://mirrors.aliyun.com|g' /etc/apk/repositories && \
    apk add --no-cache ca-certificates tzdata && \
    addgroup -S wearorder && \
    adduser -S -G wearorder -h /data -s /sbin/nologin wearorder

COPY --from=builder /out/wearorder-api /usr/local/bin/wearorder-api

USER wearorder
WORKDIR /data
EXPOSE 8080

# /healthz is cheap and always-on; if it fails for 3×30s the
# orchestrator can restart us.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/wearorder-api"]
