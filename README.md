AO RTS
======



**Goal:**

Write an AI to command your troops to gather the most resources in the time allotted.

**API**

The server will connect to your client:

You will start receiving messages in the format:


    {
      'unit-updates': [
        {id: 'XYZ', health: 2}
      ],
      'tile-updates': [
        // relative to your base
        {x: 5, y: -2, blocked: true},
      ],
    }
    
To command your units:


    {
      commands: [
        {command: "MOVE", unit: "XYZ", dir: "N"},
        {command: "MOVE", unit: "ABC", dir: "S"},
        {command: "GATHER", unit: "123", dir: "S"},
      ]
    }


**unit-updates**
**tile-updates**
	


**Commands**

_MOVE_: 
