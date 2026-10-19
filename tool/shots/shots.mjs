import { chromium } from 'playwright';
import { mkdirSync, rmSync } from 'node:fs';

rmSync('out', { recursive: true, force: true });
mkdirSync('out', { recursive: true });
const browser = await chromium.launch();
const url = 'https://hooshyar.github.io/flutter_streaming_text_markdown/';
const page = await browser.newPage({
  viewport: { width: 720, height: 1000 },
  deviceScaleFactor: 2,
  colorScheme: 'dark',
});
await page.goto(url, { waitUntil: 'networkidle' });
await page.waitForTimeout(8000);
await page.mouse.move(360, 500);
for (let i = 1; i <= 12; i++) {
  await page.mouse.wheel(0, 450);
  await page.waitForTimeout(1500);
}
await page.waitForTimeout(2000);
await page.screenshot({ path: 'out/before.png' });
await page.mouse.click(618, 196);
await page.waitForTimeout(300);
await page.mouse.wheel(0, -380);
let last = 300;
for (const ms of [1200, 2000, 2800, 3600, 5000, 9000]) {
  await page.waitForTimeout(ms - last);
  last = ms;
  await page.screenshot({ path: `out/stream-${ms}.png` });
}
for (let i = 1; i <= 3; i++) {
  await page.mouse.wheel(0, 450);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `out/end-${i}.png` });
}
await browser.close();
