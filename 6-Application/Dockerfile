FROM rocker/shiny:4.3.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN R -q -e "install.packages(c('DT','dplyr','lubridate','RPostgreSQL'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY 6-Application/ /app/

EXPOSE 8888

CMD ["Rscript", "app.R"]
