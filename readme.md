# CloudKitSharing
This repository contains code that I was using in an app I opted to discontinue development on. Said app used CloudKit to store records (chat messages, etc) between two or more people. As I was implementing this, I realized...

- How badly CloudKit is documented past the basic stuff
- How utterly broken the existing Sharing flow is

I was originally going to let this lay in my projects folder forever, but then [/u/hrothgar42 happened to ask me how I had implemented the sharing URL functionality in a more user friendly way.](https://www.reddit.com/r/swift/comments/8ivb9y/is_it_possible_to_create_a_shared_database_in/dzx3fxn/)

Thus, I figured the least I could do is dump the code here with a brief explanation of the flow. The license for this is a literal "do whatever you want with it" (and maybe give me some credit for the idea! up to you); CloudKit is honestly an amazing backing layer for apps and I really wish more apps would use it (and stop charging for it... looking at you, Bear!). Maybe this helps developers with that.

## The Flow
- On app launch, configuration flow (in `CloudKitHandler.swift`) runs and ensures that the various zones and what not exist. This is necessary for sharing to work.
- `CloudKitHandler+UserDiscovery.swift` implements logic (that you have to call, see the methods in there) to find other users in your address book that are also using your app. This is all tidied up into some nice block based callbacks.
- `CloudKitHandler+Sharing.swift` is where the real magic happens... and believe me, it's kind of magic because why this was so undocumented I'll never know. When you share a record, it dumps a row into _your public iCloud database_ for that given user's iCloud ID. The configuration blocks mentioned in the first step include an operation to check for invites when a user opens the app. If an invite exists, it grabs the share URL and manually processes accepting it.

With this, there's (very little or no) need for people to be taking a share URL, messaging it to friends, and asking them to accept it (an incredibly cumbersome and error prone process). The approach used in this code could no doubt be refined further, but I simply didn't go deeper on it. Everything in here should be used as reference for building your own - this isn't a "drag and drop" project.

## Questions, Comments, etc
- [ryan@rymc.io](mailto:ryan@rymc.io)
- [@ryanmcgrath on Twitter](https://twitter.com/ryanmcgrath)
- [rymc.io](https://rymc.io/)
