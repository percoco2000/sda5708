A simple pic16f84 library to drive an SDA5708 display, used on the NOKIA Mediamaster 9500S satellite receiver 
(Known also as DBox)
The display is composed by 7 Characters made by 5x7 pixels 
It has no char rom, so the pixels has to be addressed individually.
The library has the basic functions:

Reset the display

Clear the display

Set the brigthness

Set the char to be addressed.

Send a character

The "Send Character" routine needs to be filled, whit the pixels map
Every time the character is sent, the char position is incremented by 1
When reaced the end, wordwrap


In the repository the asm with a simple main that display a '0' in every pixel

All the infos taken from 

https://www.sbprojects.net/knowledge/footprints/sda5708/index.php

![SDA5708_Demo jpg 200x200_q85](https://github.com/user-attachments/assets/9ebd6286-6ef6-4d98-a932-71c6aae63603)
