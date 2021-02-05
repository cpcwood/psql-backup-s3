FROM alpine:3.13

RUN apk --update --no-cache add postgresql-client \
    gnupg \
    aws-cli \
    coreutils

ENV APP_HOME=/opt/app

RUN addgroup -S docker && \
  adduser -S -G docker docker && \
  mkdir -p $APP_HOME && \
  chown docker:docker $APP_HOME

USER docker

WORKDIR $APP_HOME

COPY --chown=docker:docker ./psql-backup-s3.sh .

RUN chmod 744 ./psql-backup-s3.sh

CMD ["./psql-backup-s3.sh"]




