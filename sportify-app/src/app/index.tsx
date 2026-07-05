import { StyleSheet, Text, View } from "react-native";

export default function LandingScreen() {
  return (
    <View style={styles.container} testID="landing-screen">
      <Text style={styles.title}>Sportify</Text>
      <Text style={styles.subtitle}>Coming soon</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: "center", justifyContent: "center", gap: 8 },
  title: { fontSize: 32, fontWeight: "700" },
  subtitle: { fontSize: 16, opacity: 0.6 },
});
