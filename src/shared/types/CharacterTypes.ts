export interface R6CharacterInstance extends Model {
	Humanoid: Humanoid & {
		Animator: Animator;
	};
	Head: Part;
	HumanoidRootPart: Part & {
		RootJoint: Motor6D;
	};
	["Left Arm"]: Part;
	["Left Leg"]: Part;
	["Right Arm"]: Part;
	["Right Leg"]: Part;
	Torso: Part & {
		Neck: Motor6D;
		["Left Shoulder"]: Motor6D;
		["Right Shoulder"]: Motor6D;
	};
}

export interface TWCharacterInstance extends R6CharacterInstance {
	Torso: R6CharacterInstance["Torso"] & {
		ToolJoint: Motor6D;
	};
}

export interface ViewmodelInstance extends Model {
	Humanoid: Humanoid & {
		Animator: Animator;
	};
	HumanoidRootPart: Part & {
		RootJoint: Motor6D;
	};
	["Left Arm"]: Part;
	["Right Arm"]: Part;
	Torso: Part & {
		["Left Shoulder"]: Motor6D;
		["Right Shoulder"]: Motor6D;
	};
}
