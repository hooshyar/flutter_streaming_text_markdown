import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

mkdirSync('out', { recursive: true });
const browser = await chromium.launch();
const url = 'https://hooshyar.github.io/flutter_streaming_text_markdown/';

for (const scheme of ['dark', 'light']) {
  const page = await browser.newPage({
    viewport: { width: 1280, height: 860 },
    deviceScaleFactor: 2,
    colorScheme: scheme,
  });
  await page.goto(url, { waitUntil: 'networkidle' });
  for (const t of [3, 7]) {
    await page.waitForTimeout(t === 3 ? 3000 : 4000);
    await page.screenshot({ path: `out/${scheme}-top-${t}s.png` });
  }
  await page.mouse.move(640, 500);
  for (let i = 1; i <= 4; i++) {
    await page.mouse.wheel(0, 700);
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `out/${scheme}-scroll-${i}.png` });
  }
  await page.close();
}
await browser.close();
