FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY cmd ./cmd
RUN go build -o /batix-api ./cmd/batix-server/main.go

FROM alpine:3.19
COPY --from=builder /batix-api /batix-api
EXPOSE 8080
ENTRYPOINT ["/batix-api"]
