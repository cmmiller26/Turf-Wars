import { Networking } from "@flamework/networking";
import { TWCharacterInstance } from "shared/types/characterTypes";
import { ToolType } from "shared/types/toolTypes";

interface ClientToServerEvents {
	UpdateCharacterTilt: Networking.Unreliable<(angle: number) => void>;

	EquipTool(toolType: ToolType): void;
	UnequipCurrentTool(): void;
}

interface ServerToClientEvents {
	CharacterTiltChanged: Networking.Unreliable<(character: TWCharacterInstance, angle?: number) => void>;
}

interface ClientToServerFunctions {}

interface ServerToClientFunctions {}

export const GlobalEvents = Networking.createEvent<ClientToServerEvents, ServerToClientEvents>();
export const GlobalFunctions = Networking.createFunction<ClientToServerFunctions, ServerToClientFunctions>();
