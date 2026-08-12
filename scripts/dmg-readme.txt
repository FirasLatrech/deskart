DeskArt
=======

INSTALL
  Drag DeskArt.app onto the Applications folder shown here.

FIRST LAUNCH (important)
  DeskArt is not notarised by Apple, so macOS will refuse to open it on the
  first try. This is expected for open-source apps distributed outside the
  App Store.

  To open it:
    1. Right-click (or Control-click) DeskArt in Applications
    2. Choose "Open"
    3. Click "Open" again in the dialog

  You only need to do this once.

  If macOS says the app is "damaged", clear the quarantine flag:
    xattr -dr com.apple.quarantine /Applications/DeskArt.app

PERMISSION
  On first use, macOS asks to let DeskArt control Finder. This is required —
  Finder is the only way to read and set Desktop icon positions. Click OK.
  If you decline, re-enable it in:
    System Settings > Privacy & Security > Automation > DeskArt > Finder

USING IT
  DeskArt lives in the menu bar (no Dock icon). Click the icon, pick a shape,
  press Arrange. Undo restores the previous layout.

  Turn off Desktop sorting first: right-click the Desktop > Sort By > None.
  With sorting on, Finder immediately undoes any arrangement.

Source and issues: https://github.com/FirasLatrech/deskart
