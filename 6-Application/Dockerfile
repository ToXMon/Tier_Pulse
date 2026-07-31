FROM rocker/shiny:4.3.3

ENV DEBIAN_FRONTEND=noninteractive

# System deps for RPostgreSQL + DT + package builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    postgresql-client \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install ALL required R packages (from requirements.R)
# Use -e with stop() to fail build if any package fails
RUN R -q -e "install.packages(c('shiny','bslib','DT','DBI','RPostgreSQL','lubridate','dplyr'), repos='https://cloud.r-project.org/'); for (pkg in c('shiny','bslib','DT','DBI','RPostgreSQL','lubridate','dplyr')) { if (!requireNamespace(pkg, quietly=TRUE)) stop(paste('FAILED:', pkg)) }"

WORKDIR /app
COPY 6-Application/ /app/
COPY 5-Analysis/ /5-Analysis/

EXPOSE 8888

CMD ["Rscript", "app.R"]
# rebuild trigger: GHCR login timeout retry
