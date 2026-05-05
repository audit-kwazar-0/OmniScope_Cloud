import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    baseline: {
      executor: "ramping-arrival-rate",
      startRate: 5,
      timeUnit: "1s",
      preAllocatedVUs: 20,
      maxVUs: 200,
      stages: [
        { target: 20, duration: "5m" },
        { target: 50, duration: "10m" },
        { target: 0, duration: "3m" }
      ]
    }
  },
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<300"]
  }
};

const base = __ENV.BASE_URL || "http://localhost:8081";

export default function () {
  const r1 = http.get(`${base}/hello-a`);
  check(r1, { "hello-a returns 200": (r) => r.status === 200 });

  const r2 = http.get(`${base}/call-b`);
  check(r2, { "call-b returns 200": (r) => r.status === 200 });

  sleep(0.2);
}
