const Koa = require('koa');
const static = require('koa-static');
const path = require('path') 
const app = new Koa();
const root = 'dist2';
app.use(static(
  path.join(__dirname, root)
));

app.listen(3000);