% Test whether we can produce confusion matrix programmatically

lra = LogisticRegressionApp;
lr = lra.obj;
lra.obj = lra.obj.train;

T=lra.obj.T;
Y=lra.obj.Y;
[c,cm]=confusion(T,Y);

%labels=lra.DigitPickerListBox.Value;
%plotConfMat(gca,cm,labels);

J=lra.obj.plot_mean_digit;