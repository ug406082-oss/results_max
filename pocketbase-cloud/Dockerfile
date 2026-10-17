FROM alpine:latest
RUN apk add --no-cache ca-certificates sqlite
COPY pocketbase /usr/local/bin/pocketbase
EXPOSE 8090
CMD ["pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb_data"]
