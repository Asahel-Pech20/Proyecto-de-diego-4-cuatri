import { createApp } from './app.js';
import { migrate } from './migrate.js';

const port = Number(process.env.PORT ?? 3000);

await migrate();
// 0.0.0.0 para que el teléfono en la misma red Wi-Fi pueda conectarse.
createApp().listen(port, '0.0.0.0', () => {
  console.log(`API de MiSemestre en http://localhost:${port}`);
});
