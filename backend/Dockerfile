# syntax=docker/dockerfile:1
#
# Multi-stage: build a static binary in golang:alpine, ship from
# scratch+ca-certs to keep the runtime image tiny (~25MB).

FROM golang:1.22-alpine AS builder

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
# so log timestamps render in local time.
RUN apk add --no-cache ca-certificates tzdata && \
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
