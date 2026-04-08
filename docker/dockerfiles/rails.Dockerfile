# FROM chatwoot:development
FROM chatwoot/chatwoot:develop-ce

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

USER root
RUN apk update && apk add --no-cache ca-certificates curl \
    && update-ca-certificates

RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]