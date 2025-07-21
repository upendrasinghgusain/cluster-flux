import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export let options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
};

// Utility function to generate random names and products
function randomString(prefix) {
  const suffix = Math.random().toString(36).substring(7);
  return `${prefix}-${suffix}`;
}

export default function () {
  const url = 'http://localhost:32781/api/Quote'; // 🔁 Replace this with your actual URL

  const payload = JSON.stringify({
    clientId: uuidv4(),
    customerName: randomString("customer"),
    productName: randomString("product"),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(url, payload, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
