import "package:app/src/models/item.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("contactPreferenceFromString maps known values", () {
    expect(contactPreferenceFromString("email"), ContactPreference.email);
    expect(contactPreferenceFromString("chat"), ContactPreference.chat);
    expect(contactPreferenceFromString("both"), ContactPreference.both);
  });

  test("contactPreferenceFromString falls back to both", () {
    expect(contactPreferenceFromString(null), ContactPreference.both);
    expect(contactPreferenceFromString("unknown"), ContactPreference.both);
  });

  test("contact preference helpers are consistent", () {
    expect(contactPreferenceToString(ContactPreference.email), "email");
    expect(contactPreferenceToString(ContactPreference.chat), "chat");
    expect(contactPreferenceToString(ContactPreference.both), "both");

    expect(ContactPreference.email.allowsEmail, true);
    expect(ContactPreference.email.allowsChat, false);
    expect(ContactPreference.chat.allowsEmail, false);
    expect(ContactPreference.chat.allowsChat, true);
    expect(ContactPreference.both.allowsEmail, true);
    expect(ContactPreference.both.allowsChat, true);
  });
}
