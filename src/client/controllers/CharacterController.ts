import { Components } from "@flamework/components";
import { Controller, OnStart } from "@flamework/core";
import { AbstractConstructor } from "@flamework/core/out/utility";
import { ContextActionService, Players, Workspace } from "@rbxts/services";
import Signal from "@rbxts/signal";
import { CharacterComponent, GameCharacterComponent, LobbyCharacterComponent } from "client/components/characters";
import { Events } from "client/network";
import { CHARACTER_EVENT_RATE_LIMIT, TOOL_EVENT_RATE_LIMIT } from "shared/network";
import { CharacterType } from "shared/types/characterTypes";

enum BaseAction {
	Sneak = "Sneak",
}

enum GameAction {
	EquipPrimary = "EquipPrimary",
	EquipSecondary = "EquipSecondary",

	CycleToolForward = "CycleToolForward",
	CycleToolBackward = "CycleToolBackward",

	PrimaryToolAction = "PrimaryToolAction",
	SecondaryToolAction = "SecondaryToolAction",
}

interface InputAction {
	actionName: string;
	input: (Enum.KeyCode | Enum.UserInputType)[];
	callback: (actionName: string, inputState: Enum.UserInputState) => void;
}

@Controller()
export class CharacterController implements OnStart {
	public readonly player: Player = Players.LocalPlayer;

	public get team(): Team {
		return this._team;
	}
	private set team(value: Team) {
		this._team = value;
	}
	public get camera(): Camera {
		return this._camera;
	}
	private set camera(value: Camera) {
		this._camera = value;
	}
	public get backpack(): Backpack {
		return this._backpack;
	}
	private set backpack(value: Backpack) {
		this._backpack = value;
	}
	private _team!: Team;
	private _camera!: Camera;
	private _backpack!: Backpack;

	public CharacterAdded: Signal<(characterComponent: CharacterComponent) => void> = new Signal();
	public CharacterRemoved: Signal<() => void> = new Signal();

	public get blockCount(): number {
		return this._blockCount;
	}
	public set blockCount(value: number) {
		this._blockCount = value;
		this.BlockCountChanged.Fire(value);
	}
	public get projectileCount(): number {
		return this._projectileCount;
	}
	public set projectileCount(value: number) {
		this._projectileCount = value;
		this.ProjectileCountChanged.Fire(value);
	}
	private _blockCount: number = 0;
	private _projectileCount: number = 0;

	public BlockCountChanged: Signal<(amount: number) => void> = new Signal();
	public ProjectileCountChanged: Signal<(amount: number) => void> = new Signal();

	private characterType: CharacterType = CharacterType.Lobby;
	private characterComponent?: CharacterComponent;

	private combatEnabled: boolean = false;

	private lastCharacterEventTick: number = 0;
	private lastToolEventTick: number = 0;

	private baseInputActions: InputAction[] = [
		{
			actionName: BaseAction.Sneak,
			input: [Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3],
			callback: (_, inputState): void => this.onSneak(inputState),
		},
	];
	private gameInputActions: InputAction[] = [
		{
			actionName: GameAction.EquipPrimary,
			input: [Enum.KeyCode.One],
			callback: (_, inputState): void => this.onEquipAction(0, inputState),
		},
		{
			actionName: GameAction.EquipSecondary,
			input: [Enum.KeyCode.Two],
			callback: (_, inputState): void => this.onEquipAction(1, inputState),
		},
		{
			actionName: GameAction.CycleToolForward,
			input: [Enum.KeyCode.ButtonR1],
			callback: (_, inputState): void => this.onCycleTool(1, inputState),
		},
		{
			actionName: GameAction.CycleToolBackward,
			input: [Enum.KeyCode.ButtonL1],
			callback: (_, inputState): void => this.onCycleTool(-1, inputState),
		},
		{
			actionName: GameAction.PrimaryToolAction,
			input: [Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2],
			callback: (_, inputState): void => this.onToolAction(true, inputState),
		},
		{
			actionName: GameAction.SecondaryToolAction,
			input: [Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2],
			callback: (_, inputState): void => this.onToolAction(false, inputState),
		},
	];

	public constructor(private components: Components) {}

	public onStart(): void {
		this.player.CharacterAdded.Connect((character) => this.onCharacterAdded(character));
		this.player.CharacterRemoving.Connect((character) => this.onCharacterRemoving(character));

		Events.SetCombatEnabled.connect((enabled) => this.onSetCombatEnabled(enabled));
		Events.SetCharacterType.connect((characterType) => (this.characterType = characterType));

		Events.SetBlockCount.connect((amount) => (this.blockCount = amount));
		Events.SetProjectileCount.connect((amount) => (this.projectileCount = amount));
	}

	private fetchPlayerObjects(): void {
		const team = this.player.Team;
		if (!team) error("Player does not have a team");
		this.team = team;

		const camera = Workspace.CurrentCamera;
		if (!camera) error("Missing camera in workspace");
		this.camera = camera;

		const backpack = this.player.FindFirstChildOfClass("Backpack");
		if (!backpack) error("Missing backpack in player instance");
		this.backpack = backpack;
	}

	private bindInputActions(inputActions: InputAction[]): void {
		inputActions.forEach((inputAction) => {
			ContextActionService.BindAction(inputAction.actionName, inputAction.callback, false, ...inputAction.input);
		});
	}
	private unbindInputActions(inputActions: InputAction[]): void {
		inputActions.forEach((inputAction) => {
			ContextActionService.UnbindAction(inputAction.actionName);
		});
	}

	private canFireEvent(lastEventTick: number, rateLimit: number): [boolean, number] {
		const tick = os.clock();
		if (tick - lastEventTick < rateLimit) return [false, lastEventTick];
		return [true, tick];
	}

	private getCharacterComponent<T extends CharacterComponent>(componentClass: AbstractConstructor<T>): T | undefined {
		return this.characterComponent instanceof componentClass ? this.characterComponent : undefined;
	}

	private onCharacterAdded(character: Model): void {
		print("Character added");

		this.fetchPlayerObjects();

		character.WaitForChild("HumanoidRootPart");

		print(`Constructing ${this.characterType} character component...`);

		let characterComponent: CharacterComponent;
		switch (this.characterType) {
			case CharacterType.Game:
				characterComponent = this.components.addComponent<GameCharacterComponent>(character);
				(characterComponent as GameCharacterComponent).combatEnabled = this.combatEnabled;
				this.bindInputActions(this.gameInputActions);
				break;
			case CharacterType.Lobby:
				characterComponent = this.components.addComponent<LobbyCharacterComponent>(character);
				break;
			default:
				error(`Invalid character type: ${this.characterType}`);
		}
		this.characterComponent = characterComponent;

		this.bindInputActions(this.baseInputActions);

		this.CharacterAdded.Fire(characterComponent);

		print(`${this.characterType} character component constructed`);
	}

	private onCharacterRemoving(character: Model): void {
		if (!this.characterComponent) return;

		if (this.characterComponent instanceof GameCharacterComponent) {
			this.components.removeComponent<GameCharacterComponent>(character);
			this.unbindInputActions(this.gameInputActions);
		} else {
			this.components.removeComponent<LobbyCharacterComponent>(character);
		}

		this.unbindInputActions(this.baseInputActions);

		this.characterComponent = undefined;

		this.CharacterRemoved.Fire();
	}

	private onSetCombatEnabled(enabled: boolean): void {
		this.combatEnabled = enabled;
		if (this.characterComponent instanceof GameCharacterComponent)
			this.characterComponent.combatEnabled = this.combatEnabled;
	}

	private onSneak(inputState: Enum.UserInputState): void {
		if (!this.characterComponent) return;

		if (inputState === Enum.UserInputState.Begin) {
			this.characterComponent.sneak(true);
		} else if (inputState === Enum.UserInputState.End) {
			this.characterComponent.sneak(false);
		}
	}

	private onEquipAction(slot: number, inputState: Enum.UserInputState): void {
		if (inputState !== Enum.UserInputState.Begin) return;

		const gameCharacter = this.getCharacterComponent(GameCharacterComponent);
		if (!gameCharacter) return;

		const [allowed, tick] = this.canFireEvent(this.lastCharacterEventTick, CHARACTER_EVENT_RATE_LIMIT);
		if (!allowed) return;
		this.lastCharacterEventTick = tick;

		gameCharacter.equipTool(slot);
	}

	private onCycleTool(direction: number, inputState: Enum.UserInputState): void {
		if (inputState !== Enum.UserInputState.Begin) return;

		const gameCharacter = this.getCharacterComponent(GameCharacterComponent);
		if (!gameCharacter) return;

		const [allowed, tick] = this.canFireEvent(this.lastCharacterEventTick, CHARACTER_EVENT_RATE_LIMIT);
		if (!allowed) return;
		this.lastCharacterEventTick = tick;

		gameCharacter.cycleTool(direction);
	}

	private onToolAction(isPrimaryAction: boolean, inputState: Enum.UserInputState): void {
		const gameCharacter = this.getCharacterComponent(GameCharacterComponent);
		if (!gameCharacter) return;

		const tool = gameCharacter.getCurrentTool();
		if (!tool) return;

		if (inputState === Enum.UserInputState.Begin) {
			const [allowed, tick] = this.canFireEvent(this.lastToolEventTick, TOOL_EVENT_RATE_LIMIT);
			if (!allowed) return;
			this.lastToolEventTick = tick;

			isPrimaryAction ? tool.usePrimaryAction(true) : tool.useSecondaryAction();
		} else if (inputState === Enum.UserInputState.End && isPrimaryAction) {
			tool.usePrimaryAction(false);
		}
	}
}
