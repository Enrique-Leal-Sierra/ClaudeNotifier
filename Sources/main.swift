import Foundation
import UserNotifications

// MARK: - Notification Attachment (Disabled)
//
// Use this to visually tag/categorize notifications with different images.
// The image appears as a thumbnail on the right side of the notification banner.
//
// Example use cases:
//   - Group X notifications: use "IconX.png"
//   - Group Y notifications: use "IconY.png"
//   - Error notifications: use "ErrorIcon.png"
//   - Success notifications: use "SuccessIcon.png"
//
// To enable:
//   1. Add the PNG image(s) to ClaudeNotifier.app/Contents/Resources/
//   2. Uncomment getAttachment() function below
//   3. Uncomment the attachment code in the notification section
//   4. Optionally add a -image CLI argument to specify which image to use
//
// func getAttachment(named imageName: String) -> UNNotificationAttachment? {
//     let bundle = Bundle.main
//     guard let iconURL = bundle.url(forResource: imageName, withExtension: "png") else {
//         return nil
//     }
//
//     let tempDir = FileManager.default.temporaryDirectory
//     let tempURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
//
//     do {
//         try FileManager.default.copyItem(at: iconURL, to: tempURL)
//         let attachment = try UNNotificationAttachment(
//             identifier: "image",
//             url: tempURL,
//             options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
//         )
//         return attachment
//     } catch {
//         return nil
//     }
// }

// MARK: - Argument Parsing

var title = "Claude Code"
var message = "Response complete"
var sound = true
var group = "claude-code"

var args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    switch args[i] {
    case "-title":
        i += 1
        if i < args.count { title = args[i] }
    case "-message":
        i += 1
        if i < args.count { message = args[i] }
    case "-group":
        i += 1
        if i < args.count { group = args[i] }
    case "-nosound":
        sound = false
    default:
        break
    }
    i += 1
}

// MARK: - Send Notification

let semaphore = DispatchSemaphore(value: 0)

let center = UNUserNotificationCenter.current()

center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    guard granted else {
        print("Notification permission denied")
        semaphore.signal()
        return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    if sound {
        content.sound = .default
    }
    content.interruptionLevel = .timeSensitive

    // Uncomment to add image attachment for visual tagging:
    // if let attachment = getAttachment(named: "YourImageName") {
    //     content.attachments = [attachment]
    // }

    let request = UNNotificationRequest(
        identifier: group,
        content: content,
        trigger: nil
    )

    center.add(request) { error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        semaphore.signal()
    }
}

semaphore.wait()
