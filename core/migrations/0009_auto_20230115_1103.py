# Generated by Django 2.2.28 on 2023-01-15 11:03

from django.conf import settings
import django.contrib.postgres.fields.jsonb
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0008_organization_unlimited_free_plan'),
    ]

    operations = [
        migrations.AddField(
            model_name='organization',
            name='stripe_info',
            field=django.contrib.postgres.fields.jsonb.JSONField(blank=True, null=True),
        ),
        migrations.CreateModel(
            name='Subscription',
            fields=[
                ('subscription_uuid', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False, unique=True)),
                ('stripe_product', models.CharField(max_length=255)),
                ('stripe_id', models.CharField(max_length=255)),
                ('card', models.CharField(blank=True, max_length=255, null=True)),
                ('trial_start_date', models.DateField(blank=True, null=True)),
                ('trial_end_date', models.DateField(blank=True, null=True)),
                ('subscription_start_date', models.DateField()),
                ('create_date', models.DateTimeField(auto_now_add=True)),
                ('update_date', models.DateTimeField(auto_now=True)),
                ('created_by', models.ForeignKey(blank=b'', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='subscription_creator', to=settings.AUTH_USER_MODEL)),
                ('organization', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='core.Organization')),
                ('user', models.ForeignKey(blank=b'', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='subscription_user', to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
