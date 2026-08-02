import express from 'express';
const app = express();
const server = app.listen(4000, () => {
  console.log("Listening callback called");
});
setTimeout(() => {
  console.log("Active handles:", (process as any)._getActiveHandles().length);
}, 1000);
