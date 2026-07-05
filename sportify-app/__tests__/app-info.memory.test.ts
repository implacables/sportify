import { InMemoryAppInfoRepository } from "../src/data/memory/app-info.memory";

describe("InMemoryAppInfoRepository", () => {
  it("returns 'development' by default", async () => {
    const repo = new InMemoryAppInfoRepository();
    await expect(repo.getReleaseChannel()).resolves.toBe("development");
  });

  it("returns the channel it was constructed with", async () => {
    const repo = new InMemoryAppInfoRepository("preview");
    await expect(repo.getReleaseChannel()).resolves.toBe("preview");
  });
});
