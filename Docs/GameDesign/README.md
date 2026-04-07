---
title: "Game Design Overview"
slug: /docs/game-design/overview
sidebar_position: 5
---

- [Terms](#terms)
- [Core Gameplay Loop](#core-gameplay-loop)
- [High-Level Round Loop](#high-level-round-loop)
- [Twilight Phase](#twilight-phase)
  - [Fear Points](#fear-points)
  - [Day Bonus](#day-bonus)
  - [Upgrade Uses](#upgrade-uses)
  - [Ready-Up-Flow](#ready-up-flow)
- [Fear Persistence Between Rounds](#fear-persistence-between-rounds)
- [NPC Atributes](#npc-atributes)
  - [Belief](#belief)
  - [Personalities/Architypes](#personalitiesarchitypes)
  - [Emotions](#emotions)
  - [Habits and Behaviors](#habits-and-behaviors)
- [Killing NPCs](#killing-npcs)

## Terms

**Gameplay loop:** a repeating cycle of actions including mechanics and progression, that forms the core, engaging experience of the game: Gather info, Haunt and scare, Upgrade, repeat…
**Match:** Current playing time a group of players interacts with one full cycle of the gameplay loop resulting in a win or lose condition.
**Round:** Is a singular day (24 hours).
**Phase:** Times of day which have different gameplay styles.

## Core Gameplay Loop
The goal of the gameplay loop is for the ghost players to make the NPC guests leave the house before the end of the final round.

- Current placeholder structure is 3 rounds across a weekend:
    - Friday
    - Saturday
    - Sunday
- Each round is split into:
    - Day
    - Night
    - Twilight
- The primary win condition is pushing the NPC group into a fear threshold where the majority hit critical fear and decide to leave. If that happens, the whole group leaves and the players win the game.
- If the players fail to force the NPCs out by the final round, the Match ends in failure.
---

## High-Level Round Loop

A round is a day-night cycle where there are advantages to certain mechanics based on time of day.

- Day
  - higher reward for scares
- Night
  - More Stamina
  - 
- Twilight
  - Review performance? Show each player's "Scores" based on scares
  - Check stats
  - Buy / equip upgrades with "Scare Cash" won via scares.
  - Plan the next round
  - Start the next day when all players are ready


## Twilight Phase

### Fear Points
Players earn **Fear Points** during both Day and Night.
### Day Bonus
- Fear generated during the Day is worth **2x Fear Points**.
- The logic is that seeing ghost activity in daylight is more disturbing because it breaks the expected sense of safety.
### Upgrade Uses
Fear Points can be spent to improve powers between rounds. Upgrades may:
- unlock new abilities
- enable certain abilities during daylight
- increase duration
- increase strength
- expand utility / flexibility
### Ready-Up-Flow
- Once all players choose “Begin next round”, the next round starts.
- The next round begins at Day with the newly selected powerups/loadout.

## Fear Persistence Between Rounds

Note: Emotions may impact further rounds

## NPC Atributes
NPCs attributes make NPCs unique. 
### Belief
- skeptic: Harder to scare .5 multiplier
- believer: Easier to scare 2x multiplier
- Neutral: 1x multiplier
### Personalities/Architypes
Dictates how prone to particular emotions they are, how long the emotions take to run out, could influence activities.
- Drunkard
- Headcase
- Scaredy Cat
- Smarty Pants
- Loner
- Wierdo
### Emotions
Direct modifier of behavior.
- Anger
- Sad
- Happy
- Creeped Out
### Habits and Behaviors
- cooking
- drinking
- playing games (Pool, cards, lawn games etc...)
- swiming
- using bathroom (Toilet)
- using bathroom (Shower)
- using bathroom (Tub)

## Killing NPCs
Killing NPCs ends the match. Players will have their match cut short and lose all scare points/ fear points for that round. 