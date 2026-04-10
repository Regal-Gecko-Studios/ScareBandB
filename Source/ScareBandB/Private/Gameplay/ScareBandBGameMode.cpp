// Copyright Epic Games, Inc. All Rights Reserved.

#include "Gameplay/ScareBandBGameMode.h"

#include "Characters/ScareBandBGhostCharacter.h"

AScareBandBGameMode::AScareBandBGameMode()
{
	DefaultPawnClass = AScareBandBGhostCharacter::StaticClass();
}
