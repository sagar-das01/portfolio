# Personal Portfolio Website with Courses and Guidance for interested people

## Running with Docker

This project is configured to run with Docker and Docker Compose.

### Prerequisites

*   [Docker](https://docs.docker.com/get-docker/)
*   [Docker Compose](https://docs.docker.com/compose/install/) (usually included with Docker Desktop)

### Development Environment

To run the application in a development environment with live reloading:

1.  **Build the development image and run the container:**
    ```bash
    docker-compose up dev
    ```
    Or, to build fresh:
    ```bash
    docker-compose up --build dev
    ```

2.  Open your browser and navigate to `http://localhost:3000`. Changes to files in the `src` or `public` directory will trigger a live reload in the browser.

To stop the development server, press `Ctrl+C` in the terminal where `docker-compose` is running, then run:
```bash
docker-compose down
```

### Production Environment

To build and run the application in a production-like environment:

1.  **Build the production image and run the container:**
    ```bash
    docker-compose up prod
    ```
    Or, to build fresh:
    ```bash
    docker-compose up --build prod
    ```

2.  Open your browser and navigate to `http://localhost:80` (or `http://localhost:PORT` if you changed the host port in `docker-compose.yml`).

To stop the production server:
```bash
docker-compose down
```

### Building Images Manually (Optional)

**Development Image:**
```bash
docker build -t portfolio-dev -f Dockerfile.dev .
```

**Production Image:**
```bash
docker build -t portfolio-prod -f Dockerfile .
```

### Running Containers Manually (Optional)

**Development Container (after building `portfolio-dev` image):**
```bash
docker run -p 3000:3000 -v $(pwd)/src:/app/src -v $(pwd)/public:/app/public portfolio-dev
```
*(Note: `$(pwd)` works on Linux/macOS. For Windows PowerShell, use `${PWD}`. For Windows CMD, use `%cd%`.)*

**Production Container (after building `portfolio-prod` image):**
```bash
docker run -p 80:80 portfolio-prod
```
*(You might need to use a different host port if 80 is occupied, e.g., `-p 8080:80`)*
