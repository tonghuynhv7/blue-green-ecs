const http = require("http");

const VERSION = "v1.0.1";
const BUILD_NUMBER = process.env.BUILD_NUMBER || "local";
const COLOR = process.env.APP_COLOR || "green";

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "healthy", version: VERSION, build: BUILD_NUMBER }));
    return;
  }

  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({
    message: `Hello from ${COLOR.toUpperCase()} 🚀`,
    version: VERSION,
    build: BUILD_NUMBER,
    color: COLOR,
  }));
});

server.listen(3000, () => {
  console.log(`App ${COLOR} ${VERSION} (build ${BUILD_NUMBER}) running on port 3000`);
});