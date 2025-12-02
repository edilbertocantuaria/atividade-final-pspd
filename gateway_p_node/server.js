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

// API de cat\u00e1logo: obt\u00e9m conte\u00fado do Service A
app.get("/api/content", (req, res) => {
  const type = req.query.type || "all";
  const limit = parseInt(req.query.limit || "20", 10);
  const genre = req.query.genre || "";
  
  const start = process.hrtime.bigint();
  clientA.GetContent({ type, limit, genre }, (err, response) => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    const status = err ? "error" : "success";
    grpcRequestDuration.labels("ServiceA", "GetContent", status).observe(duration);
    grpcRequestsTotal.labels("ServiceA", "GetContent", status).inc();
    
    if (err) return res.status(500).json({ error: err.message });
    res.json({
      items: response.items,
      total: response.total,
      source: "ServiceA"
    });
  });
});

// API de metadados: obt\u00e9m recomenda\u00e7\u00f5es do Service B via streaming
app.get("/api/metadata/:contentId", (req, res) => {
  const contentId = req.params.contentId;
  const userId = req.query.userId || "guest";
  
  const start = process.hrtime.bigint();
  const call = clientB.StreamMetadata({ content_id: contentId, user_id: userId });
  const metadata = [];
  
  call.on("data", (item) => {
    metadata.push({
      key: item.key,
      value: item.value,
      relevanceScore: item.relevance_score
    });
  });
  
  call.on("error", (err) => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    grpcRequestDuration.labels("ServiceB", "StreamMetadata", "error").observe(duration);
    grpcRequestsTotal.labels("ServiceB", "StreamMetadata", "error").inc();
    res.status(500).json({ error: err.message });
  });
  
  call.on("end", () => {
    const duration = Number(process.hrtime.bigint() - start) / 1e9;
    grpcRequestDuration.labels("ServiceB", "StreamMetadata", "success").observe(duration);
    grpcRequestsTotal.labels("ServiceB", "StreamMetadata", "success").inc();
    res.json({
      contentId,
      metadata,
      source: "ServiceB"
    });
  });
});

// Endpoint combinado: cat\u00e1logo + metadados do primeiro item
app.get("/api/browse", async (req, res) => {
  const type = req.query.type || "all";
  const limit = parseInt(req.query.limit || "10", 10);
  
  const start = process.hrtime.bigint();
  
  // Chama Service A para cat\u00e1logo
  clientA.GetContent({ type, limit, genre: "" }, (err, catalogResponse) => {
    if (err) {
      grpcRequestsTotal.labels("ServiceA", "GetContent", "error").inc();
      return res.status(500).json({ error: err.message });
    }
    
    grpcRequestsTotal.labels("ServiceA", "GetContent", "success").inc();
    
    // Se houver itens, busca metadados do primeiro via Service B
    if (catalogResponse.items.length > 0) {
      const firstItem = catalogResponse.items[0];
      const metaCall = clientB.StreamMetadata({ 
        content_id: firstItem.id, 
        user_id: "guest" 
      });
      const metadata = [];
      
      metaCall.on("data", (item) => metadata.push({
        key: item.key,
        value: item.value,
        relevanceScore: item.relevance_score
      }));
      
      metaCall.on("error", (err) => {
        grpcRequestsTotal.labels("ServiceB", "StreamMetadata", "error").inc();
      });
      
      metaCall.on("end", () => {
        const duration = Number(process.hrtime.bigint() - start) / 1e9;
        grpcRequestsTotal.labels("ServiceB", "StreamMetadata", "success").inc();
        httpRequestDuration.labels("GET", "/api/browse", 200).observe(duration);
        
        res.json({
          catalog: catalogResponse.items,
          total: catalogResponse.total,
          featuredMetadata: metadata,
          processingTime: `${(duration * 1000).toFixed(2)}ms`
        });
      });
    } else {
      const duration = Number(process.hrtime.bigint() - start) / 1e9;
      res.json({
        catalog: [],
        total: 0,
        featuredMetadata: [],
        processingTime: `${(duration * 1000).toFixed(2)}ms`
      });
    }
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
