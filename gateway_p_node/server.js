import express from "express";
import cors from "cors";
import morgan from "morgan";
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";
import client from "prom-client";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Prometheus metrics setup
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
});

const grpcRequestDuration = new client.Histogram({
  name: "grpc_client_request_duration_seconds",
  help: "Duration of gRPC client requests in seconds",
  labelNames: ["service", "method", "status"],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
});

const grpcRequestsTotal = new client.Counter({
  name: "grpc_client_requests_total",
  help: "Total number of gRPC client requests",
  labelNames: ["service", "method", "status"]
});

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"]
});

const PORT = process.env.PORT || 8080;
const A_ADDR = process.env.A_ADDR || "localhost:50051";
const B_ADDR = process.env.B_ADDR || "localhost:50052";

const PROTO_PATH = path.join(__dirname, "proto/services.proto");
const packageDefinition = protoLoader.loadSync(PROTO_PATH, { keepCase: true, longs: String, enums: String, defaults: true, oneofs: true });
const proto = grpc.loadPackageDefinition(packageDefinition).pspd;

const clientA = new proto.ServiceA(A_ADDR, grpc.credentials.createInsecure());
const clientB = new proto.ServiceB(B_ADDR, grpc.credentials.createInsecure());

const app = express();
app.use(cors());
app.use(morgan("dev"));
app.use(express.json());

// Middleware to track HTTP metrics
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on("finish", () => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    httpRequestDuration.labels(req.method, req.path, res.statusCode).observe(duration);
    httpRequestsTotal.labels(req.method, req.path, res.statusCode).inc();
  });
  next();
});

app.get("/", (req, res) => res.sendFile(path.join(__dirname, "public/index.html")));

app.get("/a/hello", (req, res) => {
  const name = req.query.name || "mundo";
  const start = process.hrtime.bigint();
  clientA.SayHello({ name }, (err, reply) => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    const status = err ? "error" : "success";
    grpcRequestDuration.labels("ServiceA", "SayHello", status).observe(duration);
    grpcRequestsTotal.labels("ServiceA", "SayHello", status).inc();
    if (err) return res.status(500).json({ error: err.message });
    res.json({ from: "A", message: reply.message });
  });
});

app.get("/b/numbers", (req, res) => {
  const count = parseInt(req.query.count || "5", 10);
  const delay_ms = parseInt(req.query.delay_ms || "0", 10);
  const start = process.hrtime.bigint();
  const call = clientB.StreamNumbers({ count, delay_ms });
  const values = [];
  call.on("data", (chunk) => values.push(chunk.value));
  call.on("error", (err) => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    grpcRequestDuration.labels("ServiceB", "StreamNumbers", "error").observe(duration);
    grpcRequestsTotal.labels("ServiceB", "StreamNumbers", "error").inc();
    res.status(500).json({ error: err.message });
  });
  call.on("end", () => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    grpcRequestDuration.labels("ServiceB", "StreamNumbers", "success").observe(duration);
    grpcRequestsTotal.labels("ServiceB", "StreamNumbers", "success").inc();
    res.json({ from: "B", values });
  });
});

app.get("/healthz", (_, res) => res.send("ok"));

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(PORT, () => {
  console.log(`Gateway P listening on :${PORT}`);
  console.log(`Using A at ${A_ADDR} and B at ${B_ADDR}`);
});
