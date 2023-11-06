
module AI 

    open System.Text.Json
    open System.Text.Json.Serialization
    open System
    
    type AI =
        {
            Units: int list
        }

    type UnitUpdate = 
        {
            id: int
            player_id: int
            status: string
        }

    type GameMessage =
        {
            player: int
            unit_updates: UnitUpdate list
        }

    type GameCommand =
        {
            command: string
            unit: int
            dir: string
        }

    type CommandSet =
        {
            commands: GameCommand list
        }

    let InitAI = { Units = [] }

    let processUpdate (ai: AI) (update: string) =
        let rand = new Random()
        let gameMessage: GameMessage = JsonSerializer.Deserialize update
        let updatedUnits = gameMessage.unit_updates
                        |> List.filter (fun x -> x.player_id = gameMessage.player)
                        |> List.map (fun x -> x.id)
                        |> List.append ai.Units
                        |> List.distinct
        let updatedAI = { ai with Units = updatedUnits }
        let commandSet = 
            updatedAI.Units
            |> List.map (fun x -> { command = "MOVE"; unit = x; dir = "NEWS".Substring(rand.Next(4),1) })
        (updatedAI, JsonSerializer.Serialize({commands = commandSet}))