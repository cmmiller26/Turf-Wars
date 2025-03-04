import React, { useEffect, useState } from "@rbxts/react";
import { CharacterController } from "client/controllers";
import ResourceCount from "client/ui/elements/ResourceCount";

interface ResourceDisplayProps {
	characterController: CharacterController;
}

const ResourceDisplay = (props: ResourceDisplayProps): React.Element => {
	const [blockCount, setBlockCount] = useState(0);
	const [projectileCount, setProjectileCount] = useState(0);

	useEffect(() => {
		const connections: Array<RBXScriptConnection> = [
			props.characterController.BlockCountChanged.Connect((count) => setBlockCount(count)),
			props.characterController.ProjectileCountChanged.Connect((count) => setProjectileCount(count)),
		];

		return () => connections.forEach((connection) => connection.Disconnect());
	}, []);

	return (
		<frame
			AnchorPoint={new Vector2(1, 1)}
			BackgroundTransparency={1}
			Position={UDim2.fromScale(1, 1)}
			Size={UDim2.fromScale(0, 1)}
		>
			<ResourceCount count={projectileCount} />
			<ResourceCount count={blockCount} />
			<uiaspectratioconstraint
				AspectRatio={2.5}
				AspectType={Enum.AspectType.ScaleWithParentSize}
				DominantAxis={Enum.DominantAxis.Height}
			/>
			<uilistlayout
				Padding={new UDim(0.1, 0)}
				FillDirection={Enum.FillDirection.Horizontal}
				HorizontalAlignment={Enum.HorizontalAlignment.Right}
			/>
		</frame>
	);
};

export default ResourceDisplay;
