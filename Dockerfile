FROM alpine:3.13

RUN apk --update --no-cache add postgresql-client \
    gnupg \
    aws-cli \
    coreutils

ENV APP_HOME=/opt/app

RUN mkdir -p $APP_HOME

WORKDIR $APP_HOME

RUN addgroup -S docker && \
  adduser -S -G docker docker

USER docker

COPY --chown=docker:docker ./psql-backup-s3.sh .

RUN chmod 100 ./psql-backup-s3.sh

CMD ["./psql-backup-s3.sh"]




