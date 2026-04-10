// Copyright Epic Games, Inc. All Rights Reserved.

#include "Characters/ScareBandBGhostCharacter.h"

#include "Animation/AnimSequence.h"
#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"
#include "Components/InputComponent.h"

DEFINE_LOG_CATEGORY_STATIC(LogScareBandBGhostCharacter, Log, All);

AScareBandBGhostCharacter::AScareBandBGhostCharacter()
{
	PrimaryActorTick.bCanEverTick = true;
	bReplicates = true;

	GetCapsuleComponent()->InitCapsuleSize(42.0f, 88.0f);

	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = true;
	bUseControllerRotationRoll = false;

	UCharacterMovementComponent* CharacterMovementComponent = GetCharacterMovement();
	CharacterMovementComponent->GravityScale = 0.0f;
	CharacterMovementComponent->AirControl = 1.0f;
	CharacterMovementComponent->bOrientRotationToMovement = false;
	CharacterMovementComponent->RotationRate = FRotator::ZeroRotator;
	CharacterMovementComponent->DefaultLandMovementMode = MOVE_Flying;
	CharacterMovementComponent->DefaultWaterMovementMode = MOVE_Flying;
	CharacterMovementComponent->BrakingDecelerationFlying = 2048.0f;
	CharacterMovementComponent->MaxFlySpeed = 525.0f;
	CharacterMovementComponent->MaxAcceleration = 4096.0f;

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 450.0f;
	CameraBoom->SocketOffset = FVector(0.0f, 100.0f, 110.0f);
	CameraBoom->bUsePawnControlRotation = true;
	CameraBoom->bEnableCameraLag = true;
	CameraBoom->CameraLagSpeed = 8.0f;
	// Keep the dev-camera behind the ghost instead of collapsing to the capsule in tight spawn spots.
	CameraBoom->bDoCollisionTest = false;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bAutoActivate = true;
	FollowCamera->bUsePawnControlRotation = false;

	GetMesh()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	GetMesh()->SetGenerateOverlapEvents(false);
	GetMesh()->SetAnimationMode(EAnimationMode::AnimationSingleNode);

	GhostMesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(TEXT("/Game/Art/Meshes/Characters/Ghosts/SK_Ghost.SK_Ghost")));
	GhostIdleAnimation = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(TEXT("/Game/Art/Animations/Characters/Ghosts/AN_Ghost_Idle.AN_Ghost_Idle")));
	GhostForwardAnimation = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(TEXT("/Game/Art/Animations/Characters/Ghosts/AN_Ghost_MoveForward.AN_Ghost_MoveForward")));
	GhostBackwardAnimation = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(TEXT("/Game/Art/Animations/Characters/Ghosts/AN_Ghost_MoveBackward.AN_Ghost_MoveBackward")));
	GhostLeftAnimation = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(TEXT("/Game/Art/Animations/Characters/Ghosts/AN_Ghost_MoveLeft.AN_Ghost_MoveLeft")));
	GhostRightAnimation = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(TEXT("/Game/Art/Animations/Characters/Ghosts/AN_Ghost_MoveRight.AN_Ghost_MoveRight")));

	MeshRelativeLocation = FVector(0.0f, 0.0f, -88.0f);
	MeshRelativeRotation = FRotator(0.0f, -90.0f, 0.0f);
	MeshRelativeScale3D = FVector::OneVector;
	IdleSpeedThreshold = 5.0f;
}

void AScareBandBGhostCharacter::BeginPlay()
{
	Super::BeginPlay();

	GetCharacterMovement()->SetMovementMode(MOVE_Flying);
	ApplyDefaultViewTarget();
	ResolveGhostPresentationAssets();
	RefreshAnimationState();
}

void AScareBandBGhostCharacter::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);

	ApplyDefaultViewTarget();
}

void AScareBandBGhostCharacter::OnRep_Controller()
{
	Super::OnRep_Controller();

	ApplyDefaultViewTarget();
}

void AScareBandBGhostCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	RefreshAnimationState();
}

void AScareBandBGhostCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	check(PlayerInputComponent != nullptr);

	PlayerInputComponent->BindAxis(TEXT("MoveForward"), this, &AScareBandBGhostCharacter::MoveForward);
	PlayerInputComponent->BindAxis(TEXT("MoveRight"), this, &AScareBandBGhostCharacter::MoveRight);
	PlayerInputComponent->BindAxis(TEXT("MoveUp"), this, &AScareBandBGhostCharacter::MoveUp);
	PlayerInputComponent->BindAxis(TEXT("Turn"), this, &AScareBandBGhostCharacter::Turn);
	PlayerInputComponent->BindAxis(TEXT("LookUp"), this, &AScareBandBGhostCharacter::LookUp);
}

void AScareBandBGhostCharacter::ApplyDefaultViewTarget()
{
	if (APlayerController* PlayerController = Cast<APlayerController>(Controller))
	{
		if (PlayerController->IsLocalController())
		{
			PlayerController->SetViewTarget(this);
		}
	}
}

void AScareBandBGhostCharacter::MoveForward(const float Value)
{
	if (FMath::IsNearlyZero(Value) || Controller == nullptr)
	{
		return;
	}

	const FRotator ControlRotation = Controller->GetControlRotation();
	const FRotator YawRotation(0.0f, ControlRotation.Yaw, 0.0f);
	const FVector ForwardDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::X);
	AddMovementInput(ForwardDirection, Value);
}

void AScareBandBGhostCharacter::MoveRight(const float Value)
{
	if (FMath::IsNearlyZero(Value) || Controller == nullptr)
	{
		return;
	}

	const FRotator ControlRotation = Controller->GetControlRotation();
	const FRotator YawRotation(0.0f, ControlRotation.Yaw, 0.0f);
	const FVector RightDirection = FRotationMatrix(YawRotation).GetUnitAxis(EAxis::Y);
	AddMovementInput(RightDirection, Value);
}

void AScareBandBGhostCharacter::MoveUp(const float Value)
{
	if (FMath::IsNearlyZero(Value))
	{
		return;
	}

	AddMovementInput(FVector::UpVector, Value);
}

void AScareBandBGhostCharacter::Turn(const float Value)
{
	if (!FMath::IsNearlyZero(Value))
	{
		AddControllerYawInput(Value);
	}
}

void AScareBandBGhostCharacter::LookUp(const float Value)
{
	if (!FMath::IsNearlyZero(Value))
	{
		AddControllerPitchInput(Value);
	}
}

void AScareBandBGhostCharacter::ResolveGhostPresentationAssets()
{
	GetMesh()->SetRelativeLocation(MeshRelativeLocation);
	GetMesh()->SetRelativeRotation(MeshRelativeRotation);
	GetMesh()->SetRelativeScale3D(MeshRelativeScale3D);

	if (GhostMesh.IsNull())
	{
		UE_LOG(LogScareBandBGhostCharacter, Warning, TEXT("GhostMesh is not configured. The ghost will spawn without a mesh."));
		return;
	}

	USkeletalMesh* LoadedMesh = GhostMesh.LoadSynchronous();
	if (LoadedMesh == nullptr)
	{
		LogMissingAsset(TEXT("Ghost mesh"), GhostMesh.ToSoftObjectPath());
		return;
	}

	GetMesh()->SetSkeletalMesh(LoadedMesh);

	auto LoadAnimation = [this](const TCHAR* AssetLabel, TSoftObjectPtr<UAnimSequence>& AnimationAsset)
	{
		if (AnimationAsset.IsNull())
		{
			return;
		}

		if (AnimationAsset.LoadSynchronous() == nullptr)
		{
			LogMissingAsset(AssetLabel, AnimationAsset.ToSoftObjectPath());
		}
	};

	LoadAnimation(TEXT("Ghost idle animation"), GhostIdleAnimation);
	LoadAnimation(TEXT("Ghost forward animation"), GhostForwardAnimation);
	LoadAnimation(TEXT("Ghost backward animation"), GhostBackwardAnimation);
	LoadAnimation(TEXT("Ghost left animation"), GhostLeftAnimation);
	LoadAnimation(TEXT("Ghost right animation"), GhostRightAnimation);

	if (UAnimSequence* InitialAnimation = GetFirstAvailableAnimation())
	{
		PlayGhostAnimation(InitialAnimation);
	}
}

void AScareBandBGhostCharacter::RefreshAnimationState()
{
	if (GetMesh()->GetSkeletalMeshAsset() == nullptr)
	{
		return;
	}

	UAnimSequence* DesiredAnimation = SelectAnimationForVelocity(GetActorTransform().InverseTransformVectorNoScale(GetVelocity()));
	if (DesiredAnimation == nullptr)
	{
		DesiredAnimation = GetFirstAvailableAnimation();
	}

	PlayGhostAnimation(DesiredAnimation);
}

UAnimSequence* AScareBandBGhostCharacter::SelectAnimationForVelocity(const FVector& LocalVelocity) const
{
	const FVector PlanarVelocity(LocalVelocity.X, LocalVelocity.Y, 0.0f);
	if (PlanarVelocity.SizeSquared() <= FMath::Square(IdleSpeedThreshold))
	{
		return GhostIdleAnimation.Get();
	}

	if (FMath::Abs(PlanarVelocity.X) >= FMath::Abs(PlanarVelocity.Y))
	{
		return PlanarVelocity.X >= 0.0f ? GhostForwardAnimation.Get() : GhostBackwardAnimation.Get();
	}

	return PlanarVelocity.Y >= 0.0f ? GhostRightAnimation.Get() : GhostLeftAnimation.Get();
}

UAnimSequence* AScareBandBGhostCharacter::GetFirstAvailableAnimation() const
{
	if (GhostIdleAnimation.Get() != nullptr)
	{
		return GhostIdleAnimation.Get();
	}

	if (GhostForwardAnimation.Get() != nullptr)
	{
		return GhostForwardAnimation.Get();
	}

	if (GhostBackwardAnimation.Get() != nullptr)
	{
		return GhostBackwardAnimation.Get();
	}

	if (GhostLeftAnimation.Get() != nullptr)
	{
		return GhostLeftAnimation.Get();
	}

	return GhostRightAnimation.Get();
}

void AScareBandBGhostCharacter::PlayGhostAnimation(UAnimSequence* NewAnimation)
{
	if (NewAnimation == nullptr || CurrentAnimation == NewAnimation)
	{
		return;
	}

	CurrentAnimation = NewAnimation;
	GetMesh()->SetAnimationMode(EAnimationMode::AnimationSingleNode);
	GetMesh()->PlayAnimation(NewAnimation, true);
}

void AScareBandBGhostCharacter::LogMissingAsset(const TCHAR* AssetLabel, const FSoftObjectPath& AssetPath) const
{
	UE_LOG(
		LogScareBandBGhostCharacter,
		Warning,
		TEXT("%s could not be loaded from '%s'. Import the asset to that path or update the config section for %s."),
		AssetLabel,
		*AssetPath.ToString(),
		*GetClass()->GetPathName());
}
