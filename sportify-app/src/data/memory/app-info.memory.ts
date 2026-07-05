import type { AppInfoRepository } from "../repositories";
import type { ReleaseChannel } from "../types";

export class InMemoryAppInfoRepository implements AppInfoRepository {
  constructor(private readonly channel: ReleaseChannel = "development") {}

  async getReleaseChannel(): Promise<ReleaseChannel> {
    return this.channel;
  }
}
