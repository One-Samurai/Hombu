import { test, expect } from "@playwright/test";

test("landing + login + slots render", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("h1")).toContainText("HONBU Fighter Hub");
  await page.getByRole("link", { name: /Login with Google/i }).click();
  await expect(page.getByRole("button", { name: /Continue with Google/i })).toBeVisible();
});

test("slots route renders without session", async ({ page }) => {
  await page.goto("/slots");
  // Page should load without error (no 404/500)
  await expect(page).toHaveURL(/\/slots/);
});
