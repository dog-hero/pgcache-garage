# pgCache Playground

A powerful, web-based SQL editor and benchmarking tool designed to compare the performance of direct PostgreSQL queries against pgCache.

## Features

- **Dual Connection:** Connect to both your PostgreSQL database and your pgCache instance simultaneously.
- **Schema Explorer:** Easily browse your database tables and columns directly from the UI.
- **SQL Editor:** Write custom SQL queries to test performance.
- **Parameterized Queries:** Pass dynamic parameters using a JSON array of objects (e.g., `[{"id": 1}, {"id": 2}]`).
- **Target Selection:** Choose to run benchmarks against Both databases, PostgreSQL only, or pgCache only.
- **Performance Visualization:** View real-time line charts comparing execution times (in milliseconds).
- **Statistical Summary:** Automatically calculates Mean, Median, Min, Max, and Standard Deviation for your benchmark runs, including absolute and percentage differences.

## Getting Started

### Prerequisites

- Node.js 18+
- A running PostgreSQL database
- A running pgCache instance

### Installation

1. Clone the repository and install dependencies:
   ```bash
   npm install
   ```

2. Set up your environment variables. Copy the provided `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

3. Update the `.env` file with your database credentials:
   ```env
   # Database Connection Configuration
   POSTGRES_URL=localhost:5432
   PGCACHE_URL=localhost:6432
   DB_USER=postgres
   DB_PASSWORD=secret
   DB_NAME=mydb
   ```

4. Start the development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Usage

1. **Connect:** Upon loading, the app will attempt to connect using your `.env` variables. If they are not set, a modal will prompt you to enter your connection details manually.
2. **Explore Schema:** Use the left sidebar to view your tables and columns.
3. **Write Queries:** Enter your SQL query in the editor. Use `$1`, `$2`, etc., for parameterized queries.
4. **Set Parameters:** Provide parameters as a JSON array of objects. The values are extracted in order.
   *Example:*
   ```json
   [
     { "id": 1 },
     { "id": 2 }
   ]
   ```
5. **Run Benchmark:** Select your target (Both, Postgres, or pgCache), set the number of runs per parameter, and click "Run Benchmark".
6. **Analyze:** Review the performance chart and statistical summary to compare execution times.

## Tech Stack

- **Framework:** Next.js (App Router)
- **Styling:** Tailwind CSS
- **Icons:** Lucide React
- **Charts:** Recharts
- **Database Client:** `pg` (node-postgres)
