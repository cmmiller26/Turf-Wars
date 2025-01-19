import { BaseComponent, Component, Components } from "@flamework/components";
import { OnStart } from "@flamework/core";
import { Players } from "@rbxts/services";
import { TWCharacterComponent } from "client/components/characters";
import { ToolInstance } from "shared/types/toolTypes";

const player = Players.LocalPlayer;

@Component()
export abstract class ToolComponent extends BaseComponent<{}, ToolInstance> implements OnStart {
	public get equipped(): boolean {
		return this._equipped;
	}
	protected set equipped(value: boolean) {
		this._equipped = value;
	}

	public get isActive(): boolean {
		return this._isActive;
	}
	protected set isActive(value: boolean) {
		this._isActive = value;
	}

	public get mouseIcon(): string {
		return this._mouseIcon;
	}
	protected set mouseIcon(value: string) {
		this._mouseIcon = value;
	}

	protected twCharacter!: TWCharacterComponent;
	protected animTracks!: Record<"Idle" | "Equip", AnimationTrack>;

	private _equipped: boolean = false;
	private _isActive: boolean = false;
	private _mouseIcon: string = "rbxassetid://SystemCursors/Arrow";

	public constructor(private components: Components) {
		super();
	}

	public onStart(): void {
		this.fetchTWCharacter();

		this.loadAnimations();
	}

	public equip(): void {
		if (this.equipped) {
			return;
		}
		this.equipped = true;

		this.animTracks.Idle.Play();
		this.animTracks.Equip.Play(0);
	}

	public unequip(): void {
		if (!this.equipped) {
			return;
		}
		this.equipped = false;

		for (const [, anim] of pairs(this.animTracks)) {
			anim.Stop();
		}
	}

	public abstract usePrimaryAction(toActivate: boolean): void;

	public useSecondaryAction(toActivate: boolean): void {
		warn(`Secondary action not implemented for ${this.instance.Name}`);
	}

	private fetchTWCharacter(): void {
		if (!player.Character) {
			error("No character found for local player");
		}
		const twCharacter = this.components.getComponent<TWCharacterComponent>(player.Character);
		if (!twCharacter) {
			error("No character component found for local player");
		}
		this.twCharacter = twCharacter;
	}

	private loadAnimations(): void {
		const animator = this.twCharacter.instance.Humanoid.Animator;
		this.animTracks = {
			Idle: animator.LoadAnimation(this.instance.Animations.Idle),
			Equip: animator.LoadAnimation(this.instance.Animations.Equip),
		};

		print(`Animation tracks loaded for ${this.instance.Name}`);
	}
}
