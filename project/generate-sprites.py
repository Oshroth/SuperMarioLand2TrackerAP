import json
import os
import sys
from PIL import Image
from enum import StrEnum, auto
import getopt

class Config:
    def __init__(self, config):
        self.components: dict[str, Component] = {}
        for key, component in config["components"].items():
            self.components[key] = Component(component)
        self.worlds: dict[str, World] = {}
        for key, world in config["worlds"].items():
            if world["base_image"] not in self.components:
                        print(f"Error: Missing component for ({world["base_image"]}) in {key}.base_image")
                        exit(1)
            baseImage = self.components[world["base_image"]]
            images: list[list[Component]] = []
            for imageList in world["images"]:
                imageSet: list[Component] = []
                for image in imageList:
                    if image not in self.components:
                        print(f"Error: Missing component for ({image}) in {key}.images.{imageList}")
                        exit(1)
                    imageSet.append(self.components[image])
                images.append(imageSet)
            self.worlds[key] = World(world["name"], baseImage, images, world.get("path_override"))
        self.minimumSize = Vector2(config["minimum_size"]["x"], config["minimum_size"]["y"])
        self.outputPath: str = config["output_path"]

class Vector2:
    def __init__(self, x: int = 0, y: int = 0):
        self.x = x
        self.y = y

    @classmethod
    def fromTuple(cls, size: tuple[int, int]):
        return cls(size[0], size[1])

    def __add__(self, other: Vector2) -> Vector2:
        return Vector2(self.x + other.x, self.y + other.y)
    
    def __sub__(self, other: Vector2) -> Vector2:
        return Vector2(self.x - other.x, self.y - other.y)
    
    def __mul__(self, other: int) -> Vector2:
        return Vector2(self.x * other, self.y * other)
    
    def __floordiv__(self, other: int) -> Vector2:
        return Vector2(self.x // other, self.y // other)

    def __truediv__(self, other: int) -> Vector2:
        return Vector2(self.x // other, self.y // other)
    
    def asTuple(self) -> tuple[int, int]:
        return (self.x, self.y)
    
    def max(vec1: Vector2, vec2: Vector2) -> Vector2:
        x = max(vec1.x, vec2.x)
        y = max(vec1.y, vec2.y)
        return Vector2(x, y)

class Alignment(StrEnum):
    center = "center"
    topLeft = "topLeft"
    top = "top"
    topRight = "topRight"
    left = "left"
    right = "right"
    bottomLeft = "bottomLeft"
    bottom = "bottom"
    bottomRight = "bottomRight"

class Component:
    def __init__(self, comp: dict):
        self.name: str = comp["name"]
        self.image = Image.open(comp["img"]).convert("RGBA")
        self.alignment = Alignment(comp["alignment"])
        if "offset" in comp:
            offset = comp["offset"]
            if isinstance(offset, dict):
                self.offset = Vector2(offset["x"], offset["y"])
            elif isinstance(offset, int):
                self.offset = Vector2(offset, offset)
            else:
                print(f"Error: Unknown offset at image: {self.name}")
                print(type(offset))
                exit(1)
        else:
            self.offset = Vector2()
    
    def bounds(self) -> Vector2:
        return self.size() + self.offset
    
    def size(self) -> Vector2:
        return Vector2.fromTuple(self.image.size)
    
    def getOffsetInRect(self, rect: Vector2) -> Vector2:
        match self.alignment:
            case Alignment.center:
                return (rect // 2) - (self.size() // 2) + self.offset
            case Alignment.topLeft:
                return self.offset
            case Alignment.top:
                x = (rect.x // 2) - (self.size().x // 2) + self.offset.x
                return Vector2(x, self.offset.y)
            case Alignment.topRight:
                x = rect.x - self.size().x - self.offset.x
                return Vector2(x, self.offset.y)
            case Alignment.left:
                y = (rect.y // 2) - (self.size().y // 2) + self.offset.y
                return Vector2(self.offset.x, y)
            case Alignment.right:
                x = rect.x - self.size().x - self.offset.x
                y = (rect.y // 2) - (self.size().y // 2) - self.offset.y
                return Vector2(x, y)
            case Alignment.bottomLeft:
                y = rect.y - self.size().y - self.offset.y
                return Vector2(self.offset.x, y)
            case Alignment.bottom:
                x = (rect.x // 2) - (self.size().x // 2) + self.offset.x
                y = rect.y - self.size().y - self.offset.y
                return Vector2(x, y)
            case Alignment.bottomRight:
                return rect - self.size() - self.offset

class World:
    def __init__(self, name: str, baseImage: Component, images: list[list[Component]], pathOverride: str = None):
        self.name = name
        self.baseImage = baseImage
        self.images = images
        self.pathOverride = pathOverride

args = sys.argv[1:]
options = "c:"
long_options = ["config="]

configPath = "config.json"

try:
    arguments, values = getopt.getopt(args, options, long_options)
    for currentArg, currentVal in arguments:
        if currentArg in ("-c", "--config"):
            configPath = currentVal
except getopt.error as err:
    print(str(err))
    exit(1)

with open(configPath, "r") as f:
    config = Config(json.load(f))

for world in config.worlds.values():
    canvasSize = config.minimumSize.max(world.baseImage.bounds())
    for imageSet in world.images:
        for image in imageSet:
            canvasSize = canvasSize.max(image.bounds())
    
    for imageSet in world.images:
        outputImage = Image.new("RGBA", canvasSize.asTuple())
        image = world.baseImage
        outputImage.paste(image.image, image.getOffsetInRect(canvasSize).asTuple())

        for image in imageSet:
            outputImage.paste(image.image, image.getOffsetInRect(canvasSize).asTuple(), image.image)
        
        if world.pathOverride is not None:
            outputPath = world.pathOverride
        elif len(imageSet) >= 2:
            outputPath = f"{imageSet[0].name}\\{world.baseImage.name}{imageSet[1].name}.png"
        else:
            outputPath = f"{imageSet[0].name}\\{world.baseImage.name}.png"
        
        path = os.path.join(config.outputPath, outputPath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        outputImage.save(path)
