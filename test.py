import torchvision as tv
import torchvision.transforms as transforms
from torchvision.transforms import ToPILImage
import torch.nn as nn
import torch.nn.functional as F
from torch import optim
import torch

transform = transforms.Compose([
  transforms.ToTensor(),
  transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
])

trainset = tv.datasets.CIFAR10(
  root='./data/',
  train=True,
  download=True,
  transform=transform
)

trainloader = torch.utils.data.DataLoader(
  trainset,
  batch_size=4,
  shuffle=True,
  # num_workers=2
)

testset = tv.datasets.CIFAR10(
  './data/',
  train=False,
  download=True,
  transform=transform
)

testloader = torch.utils.data.DataLoader(
  testset,
  batch_size=4,
  shuffle=False,
  # num_workers=2
)

classes = ('plane', 'car', 'bird', 'cat', 'deer', 'dog', 'frog', 'horse', 'ship', 'truck')

class Net(nn.Module):
  def __init__(self):
    super(Net, self).__init__()
    self.conv1 = nn.Conv2d(3, 6, 5)
    self.conv2 = nn.Conv2d(6, 16, 5)
    self.fc1 = nn.Linear(16 * 5 * 5, 120)
    self.fc2 = nn.Linear(120, 84)
    self.fc3 = nn.Linear(84, 10)

  def forward(self, x):
    x = F.max_pool2d(F.relu(self.conv1(x)), (2, 2))
    x = F.max_pool2d(F.relu(self.conv2(x)), 2)
    x = x.view(x.size()[0], -1)
    x = F.relu(self.fc1(x))
    x = F.relu(self.fc2(x))
    x = F.relu(self.fc3(x))
    return x

net = Net()
criterion = nn.CrossEntropyLoss()
optimizer = optim.SGD(net.parameters(), lr=0.001, momentum=0.9)

it = iter(trainloader)
print(it.next())

# torch.set_num_threads(8)
for epoch in range(2):
  running_loss = 0.0
  for i, data in enumerate(trainloader):
    inputs, labels = data
    optimizer.zero_grad()
    ouputs = net(inputs)
    loss = criterion(ouputs, labels)
    loss.backward()

    optimizer.step()

    running_loss += loss
    if i % 1000 == 0:
      print('[%d, %5d] loss: %.3f' % (epoch + 1, i, running_loss / 1000))
      running_loss = 0.0
print('finish training')