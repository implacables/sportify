import type { ExpoConfig } from "expo/config";

const config: ExpoConfig = {
  name: "Sportify",
  slug: "sportify-app",
  version: "1.0.0",
  orientation: "portrait",
  icon: "./assets/images/icon.png",
  scheme: "sportifyapp",
  userInterfaceStyle: "automatic",
  ios: {
    icon: "./assets/expo.icon",
    bundleIdentifier: "com.implacables.sportify",
  },
  android: {
    package: "com.implacables.sportify",
    adaptiveIcon: {
      backgroundColor: "#E6F4FE",
      foregroundImage: "./assets/images/android-icon-foreground.png",
      backgroundImage: "./assets/images/android-icon-background.png",
      monochromeImage: "./assets/images/android-icon-monochrome.png",
    },
    predictiveBackGestureEnabled: false,
  },
  web: {
    output: "static",
    favicon: "./assets/images/favicon.png",
  },
  plugins: [
    "expo-router",
    [
      "expo-splash-screen",
      {
        backgroundColor: "#208AEF",
        image: "./assets/images/splash-icon.png",
        imageWidth: 76,
      },
    ],
  ],
  experiments: {
    typedRoutes: true,
    reactCompiler: true,
  },
  // The "self-updatable" mechanism. `updates.url` + EAS project id are added LATER by
  // `eas init` / `eas update:configure` (online — deferred). Do not add them now.
  runtimeVersion: { policy: "appVersion" },
};

export default config;
