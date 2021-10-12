% This figure shwo the angle of detection throught time
if any(showFig == 10)
   
clf

ploth=15;
plotw=30;

figure(1)
set(gcf, 'PaperUnits', 'centimeters');
set(gcf, 'PaperSize', [plotw ploth]);
set(gcf, 'PaperPositionMode', 'manual');
set(gcf, 'PaperPosition', [0 0 plotw ploth]);


ax=gca;
colorO = ax.ColorOrder;
hr = plot(ptime,angleR,'o','color',colorO(1,:));
hold on
hm = plot(ptime,angleM,'o','color',colorO(2,:));
h2 = plot(ptime,angleA(:,2),'.','color',colorO(3,:));
h3 = plot(ptime,angleA(:,3),'.','color',colorO(4,:));

if exist('p')
hpm = plot(p.ptime,p.angleM,'p','color','r','markersize',20,'markerfacecolor','r');
end

ylabel('Angle of arrival')
xlabel('Time')

leg = legend('Real angle','First lobe','Second lobe','Third lobe','Located ping');
print('-dpng','-r150',[folderOut 'angleTime_' outName '.png' ])
end