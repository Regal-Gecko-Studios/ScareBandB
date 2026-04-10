// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "ScareBandBGhostCharacter.generated.h"

class UAnimSequence;
class UCameraComponent;
class USkeletalMesh;
class USpringArmComponent;

/**
 * Floating ghost player character implemented fully in C++.
 * Asset references are soft-configured so imported content can be swapped without a Blueprint wrapper.
 */
UCLASS(Config=Game)
class SCAREBANDB_API AScareBandBGhostCharacter final : public ACharacter
{
	GENERATED_BODY()

public:
	AScareBandBGhostCharacter();

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;
	virtual void PossessedBy(AController* NewController) override;
	virtual void OnRep_Controller() override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
	void ApplyDefaultViewTarget();
	void MoveForward(float Value);
	void MoveRight(float Value);
	void MoveUp(float Value);
	void Turn(float Value);
	void LookUp(float Value);

	void ResolveGhostPresentationAssets();
	void RefreshAnimationState();
	UAnimSequence* SelectAnimationForVelocity(const FVector& LocalVelocity) const;
	UAnimSequence* GetFirstAvailableAnimation() const;
	void PlayGhostAnimation(UAnimSequence* NewAnimation);
	void LogMissingAsset(const TCHAR* AssetLabel, const FSoftObjectPath& AssetPath) const;

	UPROPERTY(VisibleAnywhere, Category="Components")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, Category="Components")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<USkeletalMesh> GhostMesh;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<UAnimSequence> GhostIdleAnimation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<UAnimSequence> GhostForwardAnimation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<UAnimSequence> GhostBackwardAnimation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<UAnimSequence> GhostLeftAnimation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Assets")
	TSoftObjectPtr<UAnimSequence> GhostRightAnimation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Presentation")
	FVector MeshRelativeLocation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Presentation")
	FRotator MeshRelativeRotation;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Presentation")
	FVector MeshRelativeScale3D;

	UPROPERTY(Config, EditDefaultsOnly, Category="Ghost|Animation", meta=(ClampMin="0.0"))
	float IdleSpeedThreshold;

	UPROPERTY(Transient)
	TObjectPtr<UAnimSequence> CurrentAnimation;
};
