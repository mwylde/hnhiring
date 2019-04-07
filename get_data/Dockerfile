FROM ekidd/rust-musl-builder@sha256:440ecaad42b7eb0fef2f0ffa9c37e34cb8346556e4d831eb5cac1040ccf8a5ca AS build

ADD . ./

RUN sudo chown -R rust:rust /home/rust
RUN cargo build --release

# FROM alpine:3.9
FROM google/cloud-sdk:alpine

RUN gcloud components install gsutil
RUN apk --no-cache add ca-certificates
COPY --from=build /home/rust/src/target/x86_64-unknown-linux-musl/release/get_data /

RUN mkdir -p /data

CMD RUST_LOG=info /get_data /data && gsutil -h "Cache-Control:private" cp /data/* gs://www.hnhiring.me/data
