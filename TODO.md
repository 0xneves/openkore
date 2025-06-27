# Auto-Leveling Plugin: Stalker

## 🧠 Complexity Management
- Build entire game AI from scratch
- State machines to track: current level, current goal, current map, current strategy
- Decision trees for: where to level, what to kill, when to move

## 📊 Data Management
- Level progression database: What level → which map → which monsters
- Equipment progression: What gear to use/upgrade at each level
- Skill builds: Different for each job class
- Map navigation: Pathfinding between leveling zones

## ⚔️ Combat Intelligence
- Monster selection: Age-appropriate targets for each level
- Safety systems: HP/SP management, death avoidance
- Efficiency optimization: EXP/hour calculations

## 🎒 Resource Management
- Storage logic: When to store what items
- Inventory management: Potions, equipment, loot
- Economic decisions: Buy/sell strategies

## 🔄 State Persistence
- Save progress: Remember where we were if bot restarts
- Error recovery: What to do when things go wrong
- Failsafes: Stuck detection, infinite loop prevention

## 🏆 Rebirth Process
- Very server-specific - each server handles rebirth differently
- Job change mechanics
- Stat/skill reset handling

## 🛡️ Safety & Detection
- GM avoidance
- Player interaction handling
- Suspicious behavior prevention