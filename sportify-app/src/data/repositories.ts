import type { ReleaseChannel } from "./types";

/**
 * Illustrative repository proving the data-layer seam. Replace with real
 * repositories (players, venues, ...) once v0 features are defined.
 */
export interface AppInfoRepository {
  getReleaseChannel(): Promise<ReleaseChannel>;
}
