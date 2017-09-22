using System;
using Xunit;
using System.Collections.Generic;
using FluentAssertions;
using System.Linq;
using Newtonsoft.Json;

namespace ai.test
{
    public class AiTest
    {
        [Fact]
        public void Test_AI_Moves_A_Unit()
        {
            var subject = new Ai();
            var result = subject.Go(new ai.GameMessage{
                Unit_Updates = new List<UnitUpdate>{
                    new UnitUpdate{
                        Id = 5
            }}});
            result.commands.Should().NotBeEmpty();
            result.commands.First().command.Should().Equals("MOVE");
        }

        [Fact]
        public void Test_Parses_Game_Info()
        {
            string input = @"{ ""unit_updates"": [ { ""id"": 4, ""player_id"": 0, ""status"": ""idle"" } ], ""player"": 0 }";
            var result = JsonConvert.DeserializeObject<GameMessage>(input);
            result.Unit_Updates.First().Id.ShouldBeEquivalentTo(4);
        }
    }
}
