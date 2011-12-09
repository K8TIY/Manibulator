## This is Manibulator 1.0

#### I wrote this program because I am nosy, and I like to peek at other peoples' NIBs. How shameful!

#### But, I was sick of getting Interface Builder "can't open compiled NIB" errors.

Drag an application, or a whole folder full of them, into the image frame,
and if there's a NIB file anywhere in there, and it can be "manibulated",
you will see it in the pop-up menu, and you can save it as an editable NIB
file.

It's not really decompiling the NIB, the program just happens to have an empty
v2.X format NIB stored internally it can use:

* If the source file is a single file, we copy it into the internal nib as
  keyedobjects.nib.
* If the source file is a bundle, we copy it to the destination and populate
  it with classes.nib and info.nib from the internal nib.