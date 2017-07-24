using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;

namespace ai
{
    public class Ai
    {
        private Random rand = new Random();
        private HashSet<int> knownUnits = new HashSet<int>();
        public Ai()
        {
        }

        public string GoJson(string line)
        {
            var gameMessage = JsonConvert.DeserializeObject<GameMessage>(line);
            
            var commandSet = Go(gameMessage);

            return JsonConvert.SerializeObject(commandSet)+"\n";
        }

        public CommandSet Go(GameMessage gameMessage)
        {
            foreach(var unitUpdate in gameMessage.Unit_Updates){
                knownUnits.Add(unitUpdate.Id);
            }
            var gameCommands = knownUnits.Select(uid => new GameCommand{
                command = "MOVE",
                unit = uid,
                dir = "NEWS".Substring(rand.Next(4),1)
            });

            return new CommandSet { commands = gameCommands };
        }
    }
    public class GameMessage
    {
        public int Player { get; set; }
        public IList<UnitUpdate> Unit_Updates { get; set; }
    }

    public class UnitUpdate
    {
        public int Id { get; set; }
        public int Player_Id { get; set; }
        public string Status { get; set; }
    }

    public class CommandSet
    {
        public IEnumerable<GameCommand> commands;
    }
    public class GameCommand {
      public string command { get; set; }
      public int unit { get; set; }
      public string dir { get; set; }
    }
}