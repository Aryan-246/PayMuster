import express from 'express';
const app = express();
const server = app.listen(4000, () => {
  console.log("Listening callback called");
});
server.on('error', (err) => {
  console.log("SERVER ERROR", err);
});
setTimeout(() => {
  console.log("Active handles:", (process as any)._getActiveHandles().length);
}, 1000);
