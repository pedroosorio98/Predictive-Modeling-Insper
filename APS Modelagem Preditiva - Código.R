
# IMPORTANDO AS BIBLIOTECAS NECESSÁRIAS -----------------------------------

library(caret)
library(dplyr)
library(class)
library(tidyr)
library(doParallel)
library(plyr)
library(randomForest)
library(ISLR)
library(tree)
library(pROC)
library(fastAdaboost)
library(gbm)
library(gridExtra)

# IMPORTANDO A BASE CHURN -------------------------------------------------

churn <-  read.csv("churn.csv")

# ANÁLISE DESCRITIVA CHURN ------------------------------------------------

plot01 = churn %>% ggplot(aes(y = CreditScore, x = as.factor(Exited))) +
  geom_boxplot(fill = "blue") + labs(title = "Credit Score x Exited")

plot02 = churn %>% ggplot(aes(y = Balance, x = as.factor(Exited))) +
  geom_boxplot(fill = "blue") + labs(title = "Balance x Exited")

plot03 = churn %>% ggplot(aes(y = EstimatedSalary, x = as.factor(Exited))) +
  geom_boxplot(fill = "blue") + labs(title = "Salário Est x Exited")

grid.arrange(plot01, plot02, plot03,  ncol=3)

a=data.frame(tapply(churn$Exited, churn$Geography, mean))
b=data.frame(tapply(churn$Exited, churn$Gender, mean))
c=data.frame(tapply(churn$Exited, churn$NumOfProducts, mean))
d=data.frame(tapply(churn$Exited, churn$IsActiveMember, mean))

colnames(a) = c("Churned")
colnames(b) = c("Churned")
colnames(c) = c("Churned")
colnames(d) = c("Churned")


df = rbind(a,b,c,d)


rownames(df) = c("France","Germany","Spain","Female","Male","1 Product",
                 "2 Products","3 Products","4 Products","Active Member","Not an Active Member")

df$Churned = round(df$Churned*100,2)

colnames(df) = c("Churned(%)")

df

summary(churn)

# ESTRUTURANDO A BASE CHURN  ----------------------------------------------

churn$France = ifelse(churn$Geography == "France",1,0)
churn$Germany = ifelse(churn$Geography == "Germany",1,0)
churn$Male = ifelse(churn$Gender == "Male",1,0)

str(churn)

churn <- churn %>%
  select(-c(RowNumber,CustomerId,Surname,Geography,Gender )) %>%
  mutate(Exited = as.factor(as.logical(Exited)))

# DEFININDO BASE DE TESTE E TREINAMENTO -----------------------------------

train_numbers <- createDataPartition(churn$CreditScore, p = 0.5,list = FALSE)

train_set <- churn[train_numbers,]

test_set <- churn[-train_numbers,]

# KNN ---------------------------------------------------------------------

normalize <- function(x){(x - mean(x))/sd(x)}


test_set_norm <- sapply(test_set %>% select(-Exited), normalize) %>% as.data.frame()
test_set_norm$Exited <- test_set$Exited


train_set_norm <- sapply(train_set %>% select(-Exited), normalize) %>% as.data.frame()
train_set_norm$Exited <- train_set$Exited

true_prediction = c()

for (i in seq(1, 100)) {
  
  
  knn_fit <- knn(train = train_set_norm %>% select(-Exited),
                 test = test_set_norm %>% select(-Exited),
                 cl = train_set_norm$Exited,
                 k=i)
  
  true_prediction[i] <- mean(test_set_norm$Exited == knn_fit)
  
}

plot(true_prediction, xlab = "K", ylab = "Accuracy", main = "Modelos KNN, Variando o K")

best_k = which.max(true_prediction)

y_hat_knn <-  knn(train = train_set_norm %>% select(-Exited),
                  test = test_set_norm %>% select(-Exited),
                  cl = train_set_norm$Exited,
                  k=best_k,prob = TRUE)

knn_accuracy = mean(test_set_norm$Exited == y_hat_knn)

higher_prob <- attr(y_hat_knn, "prob")

prob_knn <- ifelse(y_hat_knn == TRUE, higher_prob, 1 - higher_prob)

confusion_knn <- table(Predicted = y_hat_knn, Observed = test_set$Exited)

confusion_knn

# REGRESSÃO LOGÍSTICA -----------------------------------------------------

model_reglog <- glm(Exited~.,data=train_set, family=binomial)

prob_reglog <- predict(object = model_reglog, newdata = test_set,type="response")

y_hat_reglog <- ifelse(prob_reglog>0.5,TRUE,FALSE)

reglog_accuracy <- mean(y_hat_reglog == test_set$Exited)

confusion_reglog <- table(Predicted = y_hat_reglog, Observed = test_set$Exited)

confusion_reglog

# ÁRVORES DE CLASSIFICAÇÃO ------------------------------------------------

model_ctree <- tree(Exited~.,data=train_set)

y_hat_ctree <- predict(object = model_ctree, newdata = test_set, type = "class")

ctree_accuracy <- mean(y_hat_ctree == test_set$Exited)

prob_ctree <- predict(object = model_ctree, newdata = test_set, type = "vector")[,2]

confusion_ctree <- table(Predicted = y_hat_ctree, Observed = test_set$Exited)

confusion_ctree

plot(model_ctree, type = "uniform")
text(model_ctree, cex = 0.95)

# RANDOM FOREST PARA CLASSIFICAÇÃO ----------------------------------------

model_crf <- randomForest(Exited ~ ., data = train_set)

y_hat_crf <- predict(object = model_crf, newdata = test_set)

crf_accuracy <- mean(y_hat_crf == test_set$Exited)

prob_crf <- predict(object = model_crf, newdata = test_set, type = "prob")[,2]

confusion_crf <- table(Predicted = y_hat_crf, Observed = test_set$Exited)

confusion_crf

# BOOSTING PARA CLASSIFICAÇÃO ---------------------------------------------

model_cbst <- adaboost(Exited ~ ., data = train_set, nIter = 100)

y_hat_cbst <- predict(object = model_cbst, newdata = test_set)

cbst_accuracy <- mean(y_hat_cbst$class == test_set$Exited)

prob_cbst <- y_hat_cbst$prob[,2]

confusion_cbst <- table(Predicted = y_hat_cbst$class, Observed = test_set$Exited)

confusion_cbst

# CURVAS ROC --------------------------------------------------------------

plot.roc(test_set$Exited,prob_crf,
         xlab = "False Positive Rate",
         ylab = "True Positive Rate",
         main = "Curvas ROC",col="blue",legacy.axes=TRUE)

plot.roc(test_set$Exited, prob_reglog,col = "green", add = TRUE)

plot.roc(test_set$Exited, prob_ctree,col = "red", add = TRUE)

plot.roc(test_set$Exited, prob_knn, col = "yellow", add = TRUE)

plot.roc(test_set$Exited, prob_cbst, col = "black", add = TRUE)

legend("topleft", legend = c("Random Forest", "Regressão Logística", "Árvore de Classificação"," KNN", "Boosting"),
       col = c("blue", "green", "red", "yellow", "black"), lwd = 2, cex = 0.5)


# AUC DOS MODELOS ---------------------------------------------------------

knn_auc <- auc(test_set_norm$Exited, prob_knn)

reglog_auc <- auc(test_set$Exited,prob_reglog)

crf_auc <- auc(test_set$Exited, prob_crf)

ctree_auc <- auc(test_set$Exited, prob_ctree)

cbst_auc <- auc(test_set$Exited, prob_cbst)

df_auc <- data.frame(Modelo = c("KNN", "Regressão Logística", "Árvores de Classificação"
                                ,"Random Forest","Boosting"), AUC = c(knn_auc,
                                                                      reglog_auc,ctree_auc,crf_auc,cbst_auc))
df_auc

# ACURÁCIA DOS MODELOS ----------------------------------------------------

df_accuracy <- data.frame(Modelo = c("KNN", "Regressão Logística", "Árvores de Classificação"
                                     ,"Random Forest","Boosting"), Acurracy = c(knn_accuracy,
                                                                                reglog_accuracy,ctree_accuracy,crf_accuracy,cbst_accuracy))

df_accuracy


# IMPORTANDO A BASE CARS --------------------------------------------------

cars <-  read.csv("used_cars.csv")

# ANÁLISE DESCRITIVA DA BASE CARS -----------------------------------------

plot1 <- cars %>% ggplot(aes(y = price, x = color)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Cor")

plot2 <- cars %>% ggplot(aes(y = price, x = isOneOwner)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Primeiro Dono")

plot3 <- cars %>% ggplot(aes(y = price, x = fuel)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Combustível")

plot4 <- cars %>% ggplot(aes(y = price, x = soundSystem)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Sistema de Som")

plot5 <- cars %>% ggplot(aes(y = price, x = wheelType)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Roda")

plot6 <- cars %>% ggplot(aes(y = price, x = trim)) +
  geom_boxplot(fill = "blue") + labs(title = "Preço x Trim")

grid.arrange(plot1, plot2, plot3, plot4, plot5, plot6, ncol=3)

plot7 <- cars %>% ggplot(aes(y = price, x = mileage)) +
  geom_point(color = "blue", alpha = 0.1) + labs(title = "Preço x Mileage")

plot8 <- cars %>% ggplot(aes(y = price, x = year)) +
  geom_point(color = "blue", alpha = 0.1) + labs(title = "Preço x Year")

plot9 <- cars %>% ggplot(aes(y = price, x = displacement)) +
  geom_point(color = "blue", alpha = 0.1) + labs(title = "Preço x Displacement")

grid.arrange(plot7, plot8, plot9, ncol=3)

summary(cars)

cor(cars$price,cars$displacement)
cor(cars$price,cars$mileage)
cor(cars$price,cars$year)

# ESTRUTURANDO OS DADOS ---------------------------------------------------

cars <-  read.csv("used_cars.csv")

price = cars$price

cars = model.matrix(price ~ ., data = cars)

cars = data.frame(cars)

cars$price = price

str(cars)

# DEFININDO BASE DE TESTE E TREINAMENTO -----------------------------------

train_numbers <- createDataPartition(cars$price, p = 0.7,list = FALSE)

train_set <- cars[train_numbers,]

test_set <- cars[-train_numbers,]

# REGRESSÃO LINEAR MÚLTIPLA -----------------------------------------------

model_mlr <- lm(price~., data = train_set)

y_hat_mlr <- predict(model_mlr,newdata=test_set)

MSE_mlr <- mean((y_hat_mlr-test_set$price)**2)

RMSE_mlr <- sqrt(MSE_mlr)

# ÁRVORE DE REGRESSÃO -----------------------------------------------------

model_rtree <- tree(price~.,data=train_set)

y_hat_rtree <- predict(model_rtree,newdata=test_set)

MSE_rtree <- sqrt(mean((y_hat_rtree-test_set$price)**2))

RMSE_rtree <- sqrt(MSE_rtree)

plot(model_rtree, type = "uniform")
text(model_rtree, cex = 0.95)

# RANDOM FOREST PARA REGRESSÃO --------------------------------------------

model_rrf <- randomForest(price~.,data=train_set)

y_hat_rrf <- predict(model_rrf,newdata=test_set)

MSE_rrf <- sqrt(mean((y_hat_rrf-test_set$price)**2))

RMSE_rrf <- sqrt(MSE_rrf)

# BOOSTING PARA REGRESSÃO -------------------------------------------------

train_set$isOneOwner = as.numeric(train_set$isOneOwner)
test_set$isOneOwner = as.numeric(test_set$isOneOwner)

model_rbst <- gbm(price ~ ., data = train_set, distribution = "gaussian",
                  n.trees = 1000, interaction.depth = 5,shrinkage = 0.002)

y_hat_rbst <- predict(model_rbst, newdata = test_set, n.trees = 1000)

MSE_rbst <- sqrt(mean((y_hat_rbst-test_set$price)**2))

RMSE_rbst <- sqrt(MSE_rbst)

# COMPARANDO OS MODELOS PELO RMSE -----------------------------------------

df_rmse <- data.frame(Modelo = c("Regressão Linear", "Árvores de Regressão", "Random Forest",
                                 "Boosting"), RMSE = c(RMSE_mlr,RMSE_rtree,RMSE_rrf,RMSE_rbst))
df_rmse





