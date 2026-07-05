import { render, screen } from "@testing-library/react-native";
import LandingScreen from "../src/app/index";

describe("LandingScreen", () => {
  it("renders the Sportify landing screen", async () => {
    await render(<LandingScreen />);
    expect(screen.getByTestId("landing-screen")).toBeTruthy();
    expect(screen.getByText("Sportify")).toBeTruthy();
  });
});
