import { Components } from "@flamework/components";
import { OnStart, Service } from "@flamework/core";
import { Players } from "@rbxts/services";
import { TWPlayerComponent } from "server/components";

@Service()
export class PlayerService implements OnStart {
	public constructor(private components: Components) {}

	public onStart(): void {
		Players.PlayerAdded.Connect((player) => this.onPlayerAdded(player));
		Players.PlayerRemoving.Connect((player) => this.onPlayerRemoving(player));
	}

	private onPlayerAdded(player: Player): void {
		print(`Constructing player component for ${player.Name}...`);
		this.components.addComponent<TWPlayerComponent>(player);
		print(`Player component constructed for ${player.Name}.`);
	}
	private onPlayerRemoving(player: Player): void {
		this.components.removeComponent<TWPlayerComponent>(player);
	}
}
