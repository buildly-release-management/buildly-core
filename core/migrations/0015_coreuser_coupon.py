# Generated by Django 2.2.28 on 2023-03-01 06:52

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0014_subscription_stripe_product_info'),
    ]

    operations = [
        migrations.AddField(
            model_name='coreuser',
            name='coupon',
            field=models.CharField(blank=True, max_length=48, null=True),
        ),
    ]
