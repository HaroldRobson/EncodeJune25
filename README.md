# A Letter Ahead

A Letter Ahead is a web application designed to help parents create events for their children and collect kind messages, celebratory videos, and donations. Donations go towards an ISA (Individual Savings Account) that the child can access when they turn 18, alongside the collected messages and videos. Parents can approve donations before they are processed, filtering out any undesirable messages.

The entire application is stateless aside from the database. Static HTML files are served to users, which interact with the backend via an API. Very few dependencies are used, ensuring a light codebase. Stripe is used for secure payment.

## Features

- **Parent and Child Management:** Parents can sign up and add their children to the platform.
- **Parent Portal:** Parents have a dashboard, with all their added children and curent events.
- **Donation Approval:** Parents can review and approve donations.
- **Event Creation:** Create special events for children, such as birthdays.
- **Donations:** Friends and family can donate to events.
- **Video Messages:** Donors can upload video messages for the child.
- **Stripe Integration:** Secure payment processing for donations and payouts.

## Tech Stack

- **Backend:** Go (Gin)
- **Frontend:** HTML, CSS, JavaScript
- **Web Server:** Nginx
- **Database:** PostgreSQL
- **Containerization:** Docker & Docker Compose (Self Hosted on Debian)
- **Vibe Coding** We used ACI's VibeOps platform in cursor to make the web pages.

## Project Structure

The project is divided into two main components:

- `EncodeHackathon/`: Contains the backend Go API, PostgreSQL database setup, and related Docker configurations.
- `EncodeHackathonWebDev/`: Contains the frontend static website (HTML, CSS, JS) and the Nginx server configuration.

```
.
├── EncodeHackathon/
│   ├── docker/
│   │   ├── api/      # Go API source code
│   │   └── db/       # PostgreSQL Dockerfile and schema
│   ├── docker-compose.yml  # Docker Compose for backend services
│   └── ...
└── EncodeHackathonWebDev/
    ├── web/              # Frontend static files
    ├── nginx.conf        # Nginx configuration
    ├── docker-compose.yml  # Docker Compose for frontend service
    └── ...
```

## Prerequisites

Before you begin, ensure you have the following installed on your system:

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Installation and Running

The application is fully containerized. To get it running, you need to start the backend and frontend services separately.

### 1. Start the Backend

The backend consists of the Go API and the PostgreSQL database. Note that the webpages use the exposed (ngrok) api - not a local (8080) one.
This is not an issue except for auth0 reddirect - if you go to http://localhost:8080/?parent_id=1 you can bypass auth0.

```bash
# Navigate to the backend directory
cd EncodeHackathon

# Build and start the containers in detached mode
docker compose up -d --build
```

### 2. Start the Frontend

The frontend is a static site served by Nginx.

```bash
# Navigate to the frontend directory from the project root
cd EncodeHackathonWebDev

# Build and start the container in detached mode
docker compose up -d --build
```

### 3. Access the Application

Once both services are running, you can access the web application in your browser at:

**http://localhost:8081**

## API Endpoints

The backend API provides several endpoints to manage the application's data. All endpoints are prefixed with `/api`.

-   `/events/request`: Request an event.
-   `/events/list`: Get a list of events.
-   `/events/create`: Create a new event.
-   `/donations/create`: Create a new donation.
-   `/donations/list`: List donations.
-   `/donations/approve`: Approve a donation.
-   `/uploads/video`: Upload a video.
-   `/children/list`: List children for a parent.
-   `/children/create`: Add a new child.
-   `/parents/create`: Create a new parent account.
-   `/parents/get`: Get parent details.
-   `/payments/save-account`: Handle Stripe account creation.
-   `/payments/onboarding-complete`: Update Stripe onboarding status.
-   `/payments/status`: Get payment account status.
-   `/videos/:filename`: Retrieve a video file.

For more details on the API, you can refer to the source code in `EncodeHackathon/docker/api/handlers/`.
